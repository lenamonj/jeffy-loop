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

## iter 1/10 | e4890c79-161554 | 2026-08-31 | AUDIT | audit

Task: First audit of the ada URL parser. Fill the Operating envelope, the Surface inventory and the Verify command block in PLAN.md, verify the artifact-producing channels, probe every inventory row at least shallowly, and file what the probes found.

Changed: PLAN.md (envelope surfaces, 20 inventory rows, Command/Oracle class/Environment fingerprint/Verify duration/summary pattern), BACKLOG.md (7 findings), JOURNAL.md, .gitignore (loop state file).

Checkpoint: a56b8b78a91d78a6e9261ab7696e74180b8b5842

Verification: Verify green through the installed quiet-verify.sh - "100% tests passed, 0 tests failed out of 353", 36s on a full rebuild of the ada.cpp translation unit, 1s with nothing to rebuild. Artifact channels enumerated by command, not recall: CMakeLists.txt install() rules (verified by running cmake --install into a scratch prefix - the result holds only include/ada.h, include/ada_c.h, include/ada/, lib/libada.a, the cmake package files and ada.pc, and a find for PLAN.md, BACKLOG.md, JOURNAL*.md or .jeffy returned nothing), singleheader/amalgamate.py (writes exactly ada.cpp, ada.h and ada_c.h into singleheader.zip), tools/release/create_release.py (uploads only singleheader.zip), and CPack, which cannot be a channel here because the block that would configure it is dead (finding A4). There is no Python sdist: pyproject.toml carries only ruff configuration and no build-system table. So no state file can reach a published artifact.

Probes run this iteration, all through the public API and all against an independent oracle or a scalar reference, none of them yet kept as a battery: about 660k structured and random URLs compared component-by-component between ada::url and ada::url_aggregator with can_parse and href idempotence (0 divergences); 60k structured URLs, an 18k length-sweep across the 16-byte SIMD scanner boundaries, and 33k single-byte and UTF-8 perturbations at every offset in path, query, fragment and userinfo, all compared against Node 24.17.0's URL (ada 3.4.4) (0 divergences); 1.25M IPv4 and IPv6 host strings including a systematic sweep of every "::" placement, compared against the same oracle (0 divergences); 300k relative resolutions against 14 bases (0 href divergences, and the only validity divergences are cases ada 4.x fixed in commit fbea5b01, where the spec's no-scheme state must reject a non-fragment relative reference against an opaque-path base); 300k setter calls compared against Node (the only divergence class is the host/hostname setter on an opaque-host non-special base, where this tree's "non-special:///path" is what the spec's host state override plus the empty opaque host produce and Node's older copy is the stale side); 600k setter calls checked for the rollback invariant that a setter returning false leaves href byte-identical, plus reparse idempotence, across both URL types and randomised max_input_length (0 violations); 120k URLSearchParams operations against Node (0 divergences); 40k URLPattern constructions and tests against Node's URLPattern (0 divergences in constructor acceptance, test result, or normalized component patterns); 273k known-answer percent_encode cases over all seven character sets, every byte value at every offset up to 40, against a scalar reference derived from the bitmaps, plus percent_encode_index and the bool-returning overload (0 divergences); 200k C API parses compared field-by-field against the C++ API (0 divergences); 217k url_components offset checks against the documented layout (0 violations); and 400k parses under randomised max_input_length checking can_parse/parse agreement and that no accepted href exceeds the limit (0 violations).

Scores, claiming only what those probes reached and explicitly not the unswept remainder - every one of the 20 inventory rows is still [ ] because no probe was kept as a battery this iteration: correctness High (A1, A2), error handling High (A2), documentation Medium (A3), testing Low (A5, A6), developer experience Low (A4, A7), security None on the parsing surface probed, architecture None, code quality None, dependency hygiene None (CPM pins gtest, simdjson and google/benchmark to explicit versions and no transitive lockfile drift was visible), observability None, performance not scored - no benchmark was run and the Method's ordering puts correctness first. UX/accessibility applies only to the adaparse CLI, whose findings are A2 and A3.

The AVX-512 IPv4 and IPv6 kernels are the one part of the mapped surface this host cannot execute: the CPU is an Intel Core Ultra 5 135U with no AVX-512, and neither qemu-user nor Intel SDE is installed. They were read rather than run, and A1 is what reading them plus a compile found. Their row stays [ ] rather than [~] because a host with AVX-512 can sweep it, and the Environment fingerprint says plainly that no journal entry may call them green here.

Learnings: The Verify command line in PLAN.md is executed verbatim by quiet-verify.sh, which does not strip wrapping backticks - a backtick-wrapped command becomes a command substitution and the gate reports exit 127 on a healthy suite. ctest's summary line is "100% tests passed, 0 tests failed out of 353", whose first integer is the percentage and not the total, so Verify count is deliberately left empty.

Next: A1, the AVX-512 IPv6 build failure, then A2, the adaparse exit status. Both are Highs and both outrank the unswept inventory rows.

## iter 2/10 | e4890c79-161554 | 2026-08-31 | A1 | done

Task: A1 (High, runtime, correctness) - the AVX-512 IPv6 host kernel called BMI1 and BMI2 intrinsics under a guard that names only AVX-512 feature macros, so a build enabling exactly the features the file's own comment calls for failed to compile.

Changed: include/ada/url_ip-inl.h (three intrinsic uses now sit inside a #if naming their own feature macro, each with a portable fallback), BACKLOG.md (A1 deleted, Settled classes line added), PLAN.md (Verify duration re-measured), JOURNAL.md.

Checkpoint: 89021c4993690f1e477c2241774ae7ee21e5c07d

Verification: The filed reproduction ran first and failed as filed - g++ -std=c++20 -O2 -c -mavx512bw -mavx512vl -mavx512vbmi -mavx512vbmi2 -I include src/ada.cpp exited 1 with 5 errors, "inlining failed in call to always_inline" for _bzhi_u64, _bzhi_u32 and _blsr_u64 at three sites in include/ada/url_ip-inl.h. After the fix that command exits 0, and so does every other combination in the matrix actually driven: no flags, BW+VL, BW+VL+VBMI2, BW+VL+VBMI+VBMI2, that set plus -mbmi -mbmi2, -march=x86-64-v4, -march=icelake-server, -march=sapphirerapids, -march=znver4 and -march=native, under g++ 15.2.0, plus BW+VL+VBMI+VBMI2 and -march=x86-64-v4 under clang++. The substitution is not an approximation and was not taken on trust: this CPU has BMI1 and BMI2, so a separate program compiled with -mbmi -mbmi2 compared each intrinsic against its replacement over the whole domain the kernel uses - _bzhi_u64(~0ULL, len) against ~0ULL >> (64 - len) for every len in [2, 45], the kernel's own bound; _bzhi_u32(0xFFFFFFFFu, 8 - kept) against the conditional form for every kept in [0, 16], the full range of a 16-bit popcount, including the kept > 8 wrap where the intrinsic returns its input; and _blsr_u64 against x & (x - 1) over 200000 values plus zero - and reported 0 mismatches. Behaviour on hardware that has BMI2 is therefore unchanged: the intrinsic path is still taken verbatim there. Verify green through the installed quiet-verify.sh: "100% tests passed, 0 tests failed out of 353".

Contract preserved: try_parse_ipv6_avx512 keeps its signature, its callers in src/url.cpp and src/url_aggregator.cpp are untouched, and the kernel is still selected by exactly the same ADA_AVX512_IPV6 condition, so no build that compiled it before stops compiling it and no build that used the scalar parser starts using the kernel. Nothing documented changes, so no documentation edit was owed and no Surface inventory row moved - none is swept yet.

Class rather than instance: the finding was one of a class, and the class is closed. The enumeration grep -rn '_bzhi_u\|_blsr_u\|_blsi_u\|_bextr_u\|_pdep_u\|_pext_u\|_tzcnt_u\|_lzcnt_u\|_andn_u' include src tools returns 4 call sites, and all 4 are now inside a #if defined(__BMI__) or #if defined(__BMI2__) with a fallback beside it. The fourth, in include/ada/checkers-inl.h, already carried that guard - the IPv4 kernel established the pattern and the later IPv6 kernel did not follow it, which is exactly why the flag combination that reaches only the IPv6 kernel was the one that broke.

Learnings: A header change rebuilds the library, every test binary and the single-header lib, so the gate takes about 108s rather than the 36s a source-only change costs; the Verify duration line now records the header figure so the converged-stop bound is sized to the worse case. The AVX-512 kernels still cannot be executed on this host, so this fix is evidenced by compilation across the flag matrix and by proving the scalar substitutions equal the intrinsics, never by running the kernel.

Next: A2, the adaparse exit status, the run's remaining High.

## iter 3/10 | e4890c79-161554 | 2026-08-31 | A2 | done

Task: A2 (High, runtime, error handling) - adaparse tested piped_file's int return as a boolean, so its EXIT_SUCCESS (0) became the false branch and every non-tty invocation exited 1 no matter what it had done.

Changed: tools/cli/adaparse.cpp (propagate piped_file's status at both call sites; make an unrecognized -g part a non-zero exit in piped mode as it already was for a single URL), BACKLOG.md (A2 deleted), JOURNAL.md.

Checkpoint: 96e1dfc310f8ceba22e0560853defdc58f07b34a

Verification: The filed reproduction ran first and failed as filed - printf 'https://example.com/\n' | adaparse -g host printed example.com and exited 1. After the fix the same command prints example.com and exits 0, which is A2's acceptance as written. The prose claim that this was "every non-tty invocation" was not left as an assertion: main's exit paths were enumerated by provoking each one rather than by reading the source, and all 17 were driven before and after - piped with no -g, with -g href, with -g host over two URLs, with an invalid URL, with empty stdin, with an unknown -g part, with input lacking a trailing newline so the tail branch after the read loop is taken, and that tail branch with an unknown part; and, through script -qec for a tty stdin, -p over a readable file, -p with an unknown part, -p on a missing file, --help, no arguments, a valid URL, an invalid URL, -g host, -g with an unknown part, and -d. Before the fix all eight piped routes exited 1. After it, every route exits 0 on success and 1 on a real error, and the tty routes are byte-for-byte unchanged in both output and status. Verify green through the installed quiet-verify.sh: "100% tests passed, 0 tests failed out of 353" - the suite does not build tools, so it confirms the library is unharmed rather than the CLI is fixed, and the CLI evidence is the matrix above.

One behaviour change beyond the literal reproduction, recorded because it would otherwise read as a regression: adaparse -g <unknown-part> over a pipe exited 1 before this iteration and would have exited 0 after propagating the status, because piped_file discarded print_part's false. That old 1 was the inversion bug rather than a signal - every piped run exited 1, success and failure alike, so the status carried no information at all. Leaving it at 0 would have left piped mode contradicting the single-URL path, which exits 1 on exactly the same argument, so piped_file now tracks print_part's result and returns EXIT_FAILURE when the part name was never recognized. Both modes now agree on every input in the matrix. Invalid URLs inside the stream are still reported per line and still do not change the exit status; that was the behaviour before and this iteration did not touch it.

Contract preserved: piped_file keeps its signature and its int return, the -p branch now propagates that status instead of discarding it and hardcoding EXIT_SUCCESS, and no option, output format or diagnostic text changed. Nothing in README.md or docs/cli.md documents an exit status, so no documentation was owed. No Surface inventory row moved - none is swept yet, and the adaparse row stays unswept for a sweep iteration to evidence properly.

Learnings: adaparse's exit status is invisible from an ordinary tool invocation here because a non-tty stdin sends it down the piped path regardless of argv; both routes have to be driven, the pipe directly and the tty one through script -qec, or half the exit paths are never seen. clang-format is not installed on this host, so the edits were kept inside 80 columns by hand and checked with awk rather than by the formatter AGENTS.md names.

Next: no High remains, so the queue turns to the 20 unswept Surface inventory rows, which outrank the open Medium and the four Lows.

## iter 4/10 | e4890c79-161554 | 2026-08-31 | SWEEP | done

Task: Sweep Surface inventory rows. The map outranks everything but an open High, no High remains, and 20 rows were unswept with 7 iterations left, so this iteration built kept batteries and swept every row it could properly evidence.

Changed: .jeffy/probes/ (a shared instrument under lib/ plus nine batteries: percent-encoding, host-ip-scalar, serializers, url-components, aggregator-setters, url-search-params, c-api, parse-fast-paths and avx512-compile, each with its paths, claims and README), PLAN.md (nine Surface inventory rows and one Lesson), JOURNAL.md.

Checkpoint: c2d863d53e3401df103497695a38a729c7f07dbb

Verification: Every battery is a known-answer or invariant check and none of them passes because a call did not crash. All nine run green through the installed run-probe.sh, and skills/jeffy/hooks/lib/check-claims.sh reports 8 checked, 0 mismatched, 0 errored, 0 skipped over the eight claims files that existed when it ran. Verify green through the installed quiet-verify.sh: "100% tests passed, 0 tests failed out of 353".

No battery was trusted until it had been seen to fail. Two scratch copies of the tree were mutated and built, and each battery's discriminating mutation is recorded in its own README: the hex table entry for 0x20 rewritten (percent-encoding, 62557/62732); the octal digit guard widened from '7' to '9' so http://08/ parses (host-ip-scalar, 4043/4044); remove(key, value) made to ignore the value (url-search-params, 20026/20027); ada_has_port negated (c-api, 17163/60003); the fragment empty-rule changed from <= 1 to < 1 (url-components, 32549/43378); set_port made to clear the port before returning false (aggregator-setters, 238514/240000); is_ascii_tab_or_newline made to stop recognizing carriage return (parse-fast-paths, 21106/21569); and, for avx512-compile, the tree at e6754478 before A1 was fixed, where it reports 8/9 and names the flag combination. In the first mutant round the batteries not targeted by that round's mutations all stayed green, so each attribution is to one mutation rather than to the round.

That discipline paid immediately. The serializers battery stayed green under a real mutation - the IPv6 compression threshold widened from "longest run greater than one" to "greater than two" - because not one of its cases had a longest zero run of exactly two, which is the only place that mutation is visible. Three run-of-two cases were added, at the front, the middle and the end of the address, and the battery then reported 14/17 on that mutant and 17/17 on the real tree. An instrument that had never been observed failing would have certified that row while blind to its own boundary.

Writing the batteries also corrected five wrong expectations in the instrument itself, all of them mine and none of them product defects: the form-urlencoded set leaves '*' unencoded; "0xg" is not an IPv4 number so the host stays a domain; "1:2:3:4:5:6:7::" is legal because "::" there elides exactly one group; ada::serializers::ipv6 already returns the bracketed form; and max_input_length bounds parsing rather than every later setter, so a setter on an already-longer URL is not obliged to fail.

Rows swept, nine of twenty: parse entry points and fast paths, host parsing scalar, IPv4/IPv6 serializers, percent encoding and decoding, url_search_params, url_components, url_aggregator setters, the C API, and - as a disclosure rather than a sweep - the AVX-512 kernels, which this host cannot execute and which are marked [~] with that reason. Eleven remain: the top-level API, aggregator getters, ada::url, IDNA, helpers, url_pattern core, url_pattern helpers, scheme handling, the adaparse CLI, build and packaging, and the support headers.

Learnings: A battery is not an instrument until it has been observed failing on the product, and the mutation has to be chosen to sit at the boundary the battery claims to cover, not merely somewhere in the same file. Batteries that share paths with each other are fine and are what keeps a row honest when a sibling file moves.

Next: the remaining eleven inventory rows, which still outrank the open Medium and the four Lows.

## iter 5/10 | e4890c79-161554 | 2026-08-31 | SWEEP | done

Task: Continue sweeping Surface inventory rows. Eleven were unswept with six iterations left, so this iteration built batteries for eight more rows; two of them came back red on real defects, which were filed rather than swept past.

Changed: .jeffy/probes/lib/ada_probe.cpp (eight new groups), eight new battery directories (top-level-api, aggregator-getters, helpers, scheme, url-pattern-core, url-pattern-helpers, and the two red ones, idna and url-class), PLAN.md (six rows), BACKLOG.md (A8 and A9 filed), JOURNAL.md.

Checkpoint: b9b2dd2a48fb163ad58f432e8ca1fcc4dcdb9835

Verification: Six batteries green through the installed run-probe.sh, and check-claims.sh reports 15 checked, 0 mismatched, 0 errored, 0 skipped. Verify green through the installed quiet-verify.sh: "100% tests passed, 0 tests failed out of 353". The two red batteries carry no claims file on purpose: they are the reproductions for A8 and A9, and a known product defect must not read as the loop's own instrument drifting. Their claims lines are written when the fixes land, which is what lets their rows be swept.

A8, filed High. The sweep of the IDNA row compared this tree against Node 24.17.0, whose URL parser is ada 3.4.4, and found a family of hostnames this tree accepts and that one rejects: xn--a, xn--, xn---, xn--0, xn--zz, xn--a-, xn--a.example and b.xn--a, while xn--7a and xn--pokmon-xia are accepted by both. Reading found the cause rather than guessing it: to_ascii in src/ada_idna.cpp returns early for any ASCII domain with a lowercase copy, so an xn-- label in a pure-ASCII domain never reaches the punycode validation the same file implements. The comment above that early return quotes the WHATWG note that licenses it but drops the note's own condition, which excludes domains where splitting on U+002E produces an item starting with an ASCII case-insensitive match for "xn--". The reproduction that settles it is not the comparison but the tree's own inconsistency: https://xn--a.example/ is accepted and https://xn--a.münchen.de/ is rejected, the identical label with a different sibling, because only the second one takes the full path. Under this project's Operating envelope the URL string is adversarial, and the consequence a user of the shipped product meets is that ada canonicalizes a hostname every browser refuses, so an allowlist or origin comparison built on it disagrees with the rest of the stack.

A9, filed High. The url-class battery compares ada::url and ada::url_aggregator field by field as two implementations of one documented contract, and they disagree on get_components().host_end for every URL with a host. include/ada/url-inl.h subtracts one in the no-credentials branch and omits the '@' in the credentials branch, so a consumer slicing the href by [host_start, host_end) gets a truncated host - for https://e.com/a the host is at [8, 13) and ada::url reports 13 as 12. The running index computed just after it adds the one back, which is why every other offset agrees and why this survived: tests/url_components.cpp never mentions host_end. The struct's own documentation diagram puts host_end one past the host, and the aggregator matches it.

Writing these batteries again corrected several instrument bugs before they could certify anything: two C++ hex escapes were being read greedily so "\x0bb" was one character rather than two; a trailing space is trimmed from the whole input, so it is not an interior space; a backslash in a non-special authority is a forbidden host code point rather than a kept character, so the special-versus-non-special difference has to be compared in the path; and ada::helpers is declared in a public header but defined only inside the library's own translation unit, so it cannot be linked from outside and the helpers row is swept through the behaviour it implements instead.

Rows swept this iteration, six: the top-level API, aggregator getters, helpers, scheme handling, url_pattern core and url_pattern helpers. That is fourteen of twenty swept, one unreachable, five unswept: IDNA and ada::url, both blocked behind the findings above, plus the adaparse CLI, build and packaging, and the support headers.

Learnings: A differential against a different version of the same library is worth running even though it is not an independent implementation - it found A8 - but the finding only became evidence when the tree was shown to contradict itself on the same input. When a battery goes red on a real defect, leave its claims file out until the fix lands, or the claims checker reports a product defect as instrument drift.

Next: A8 and A9 are open Highs and outrank the five remaining rows.

## iter 6/10 | e4890c79-161554 | 2026-08-31 | A8 | done

Task: A8, the High this run filed in iteration 5 claiming that to_ascii skips punycode validation for pure-ASCII domains. The fix was written, the gate refused it, and the investigation that followed showed the finding's premise was false. A8 is withdrawn to Declined, the residual question goes to Proposed, and the IDNA row is swept against the project's own corpus.

Changed: .jeffy/probes/lib/ada_probe.cpp (the idna group rewritten around the corpus), .jeffy/probes/idna/ (claims and README added), .jeffy/probes/lib/build.sh (always rebuild the library), BACKLOG.md (A8 to Declined, one Proposed item), PLAN.md (the IDNA row and two Lessons), JOURNAL.md. src/ada_idna.cpp is unchanged: the fix that was written there is reverted and is not in this checkpoint.

Checkpoint: 27fbf6ff1df6441b52fe525943ff9afd984d1645

Verification: The fix was attempted once and reverted, not attempted three times, because the second command told me the premise was wrong rather than the patch. Narrowing the ASCII short-circuit so a domain carrying an xn-- label takes the full UTS46 pass made the idna battery go 28/28, and then the Verify gate failed with 9 of 353 tests red, among them wpt_url_tests.idna_test_v2_to_ascii asserting that "xn--ab-j1t" must map to itself and getting "". src/ada_idna.cpp was restored with git checkout and the gate is green again: "100% tests passed, 0 tests failed out of 353". Every battery is green through the installed run-probe.sh and check-claims.sh reports 16 checked, 0 mismatched, 0 errored, 0 skipped.

Why A8 was wrong. It rested on Node 24.17.0 rejecting a family of hostnames this tree accepts. Node is the wrong oracle here: of the 960 pure-ASCII domains carrying an xn-- label in tests/wpt/IdnaTestV2.json, Node rejects 761 that the corpus expects accepted and accepts none that the corpus expects rejected. The corpus is this project's own oracle and it names the exact inputs the finding was built on - xn--a.pt, xn--0.pt and xn-- are all listed with themselves as the expected output - so the ASCII short-circuit is required behaviour rather than a skipped validation. I also mis-stated the WHATWG note that licenses the shortcut: I asserted from memory that it excludes domains with an xn-- label, and the corpus is the evidence that my recollection was the weak link. The Declined line records the command that reads those three expectations out of the corpus, so the premise is re-checkable rather than a claim.

What survives. The tree really does give one xn-- label two verdicts: https://xn--a.example/ parses and https://xn--a.münchen.de/ does not, because only the second takes the full pass, and a valid ACE label survives both (https://xn--pokmon-xia.münchen.de/ parses). The corpus requires the accepting side and contains no invalid ACE label beside a non-ASCII one, so which side is wrong cannot be evidenced from here. That is a spec-interpretation decision, so it went to Proposed rather than back onto the ledger at a severity I cannot support.

The IDNA row is now swept, and the battery holds both paths apart on purpose: the ASCII answers are cited to the corpus with the command that reads them, and the full-pass answers are the mixed-domain cases the corpus also carries. Its recorded failing state is the patch this iteration discarded, which takes it to 24/26 - the right discriminating state for a row whose whole subtlety is that it has two paths.

One instrument defect was found and fixed on the way: .jeffy/probes/lib/build.sh only built the library when it was missing, so the first run of the idna battery after editing src/ada_idna.cpp measured a stale archive and reported the pre-fix number. It now always builds, and the mutant path is gated behind an explicit ADA_PROBE_LIB. A battery that can certify a stale library is worse than no battery.

Learnings: Node's URL is not an oracle for IDNA, and a divergence against it has to be checked against tests/wpt/IdnaTestV2.json before it is a finding. A scratch mutant tree needs -DADA_INCLUDE_URL_PATTERN=ON -DADA_USE_UNSAFE_STD_REGEX_PROVIDER=ON or the probe cannot link against it. When a fix makes a battery green and the conformance suite red, the suite is the one to believe.

Next: A9, the ada::url host_end off-by-one, which is the run's remaining High.

## iter 7/10 | e4890c79-161554 | 2026-08-31 | A9 | done

Task: A9 (High, runtime, correctness) - url::get_components() reported host_end one byte short, so a consumer slicing the href by [host_start, host_end) got a truncated host while url_aggregator returned the documented offset for the same URL.

Changed: include/ada/url-inl.h (both branches of the host_end computation and the running index that compensated for the old one), tests/url_components.cpp (an assertion that pins host_end, which nothing did before), .jeffy/probes/url-class/ (claims and README added), BACKLOG.md (A9 deleted), PLAN.md (two rows re-recorded), JOURNAL.md.

Checkpoint: b4d86aac976c1f90a69d01ee0d029c4ce7581eb7

Verification: The filed reproduction ran first and failed as filed - .jeffy/probes/url-class/run.sh reported 16347/80000 - and reports 80000/80000 after the fix, which is A9's acceptance as written. Verify green through the installed quiet-verify.sh: "100% tests passed, 0 tests failed out of 353". Every battery under .jeffy/probes was run through the installed run-probe.sh and all seventeen are green; check-claims.sh reports 17 checked, 0 mismatched, 0 errored, 0 skipped. Two batteries declare paths this diff touched, aggregator-setters and url-class, and both were re-run and their rows re-recorded at this checkpoint.

The regression test was proved to fail before it was trusted. tests/url_components.cpp sliced the hostname by get_hostname().size() and never mentioned host_end, which is exactly why the project's own suite was green over a one-byte error; the fix adds a slice bounded by host_end instead. To confirm that assertion can fail, the fixed header was copied aside, the old computation restored in place, url_components rebuilt and that one test run: it failed. The header was then restored from the copy rather than with git checkout, because the path carried the uncommitted fix.

The arithmetic, since an off-by-one is easy to move rather than remove. With credentials, host_start is the '@' - both implementations report it that way - so the host begins one byte later and host_end is host_start + 1 + host size. Without credentials, host_start is the host itself and host_end is host_start + host size. The old code subtracted one in the second branch and omitted the '@' in the first, then set running_index to host_end + 1, which put the post-host index back where it belonged; that compensation is why every later offset was already correct and why only host_end was wrong. running_index is now host_end, so the later offsets are unchanged, which the 80000-case comparison against url_aggregator confirms field by field.

Contract preserved: no signature changes, and host_end now matches the diagram documented in both include/ada/url.h and include/ada/url_components.h and the value url_aggregator has always returned, so the documentation needed no edit. url::get_components() has no caller inside the library - the two call sites in src/parser.cpp are in the url_aggregator arm of an if constexpr, and the C API's instance type is the aggregator - so the change reaches external consumers and the tests, benchmarks and fuzz harnesses only.

Learnings: When a public accessor is wrong and a nearby index silently compensates for it, the compensation is what hides the defect from every downstream assertion; fix both together and re-check the downstream fields rather than assuming they moved. A regression test written alongside a fix has to be run against the unfixed code before it is believed, and the fixed file is copied aside for that, never git-checked-out.

Next: no High or Medium above the four remaining Lows except A3; the queue puts the four unswept inventory rows next - the adaparse CLI, build and packaging, the support headers, and nothing else.

## iter 8/10 | e4890c79-161554 | 2026-08-31 | SWEEP | done

Task: Sweep the last three Surface inventory rows - the adaparse CLI, build and packaging, and the support headers. The sweep surfaced one High, which is filed rather than swept past.

Changed: .jeffy/probes/lib/ada_probe.cpp (a support-headers group), three new battery directories (adaparse-cli, packaging, support-headers), PLAN.md (three rows), BACKLOG.md (A10 filed), JOURNAL.md.

Checkpoint: 6260a3c41f65db5ab724182b740bb7bf15bf48a1

Verification: All three batteries green through the installed run-probe.sh - adaparse-cli 32/32, packaging 20/20, support-headers 22/22 - and check-claims.sh reports 20 checked, 0 mismatched, 0 errored, 0 skipped over every battery this run has written. Verify green through the installed quiet-verify.sh: "100% tests passed, 0 tests failed out of 353". No product code changed this iteration.

Each battery's failing state was measured rather than guessed, and the first two guesses were both wrong. The CLI battery run against the tree at 3fe77821, before A2 was fixed, reports 23/32 and not the 19 I expected: every piped route that should exit 0 exits 1 there, and the -p route with an unknown -g part exits 0 because piped_file discarded print_part's result. The packaging battery run against a tree with include/ada/url_ip-inl.h deleted reports 9/20 and not 17, because the deletion takes the build down and everything downstream with it. The arm of the packaging battery that matters most - that no state file reaches a published artifact - cannot be reddened by deleting a header, so it was checked on its own by pointing the same find at the project root, where it returns 4 rather than 0.

A10, filed High. The packaging battery originally compiled its consumer at -O1 and the single-header compile failed. That is not a packaging defect: g++ -std=c++20 -O1 -I include -c src/ada.cpp fails on the library itself with 8 errors, and fails identically at the base commit e6754478, so it is neither this run's doing nor specific to the amalgamation. Ten call sites pass an ada_really_inline predicate by name to a std::ranges algorithm and GCC refuses to inline an always_inline function through std::__invoke at -O1. The enumeration is the compiler's own: it names is_ascii_digit, is_alnum_plus and is_forbidden_host_code_point reached from parse_opaque_host, set_port, set_protocol and canonicalize_port across src/url.cpp, src/url_aggregator.cpp, src/url_pattern_helpers.cpp and src/unicode.cpp, built by provoking the failure rather than by grepping for the calls. -O0, -O2, -O3 and -Og all compile and clang compiles at every level, which is why no CI job meets it; a distro or consumer building at -O1 gets a hard failure, which the rubric scores High as a broken build a user performs. The packaging battery's consumer compile was moved to -O2, the level the project itself ships, so that battery measures its own row and A10 carries its own reproduction.

The map is now complete: nineteen of twenty rows swept, one disclosed as unreachable, none unswept. That was the run's bound, and it is spent.

Learnings: A battery's recorded failing state has to be measured on the mutant, not predicted from reading the diff - both predictions this iteration were wrong, and one of them was wrong in an interesting way. When a probe surfaces a defect outside its own row's scope, move the probe back to its row and give the defect its own reproduction, rather than leaving a battery permanently red about something it does not own.

Next: A10 is the only open High and outranks everything; the map no longer competes with it.

## iter 9/10 | e4890c79-161554 | 2026-08-31 | A10 | done

Task: A10 (High, runtime, correctness) - the library did not compile with g++ at -O1, because ten call sites passed an ada_really_inline predicate by name to a std::ranges algorithm and GCC will not inline an always_inline function reached through std::__invoke.

Changed: src/url.cpp, src/url_aggregator.cpp, src/checkers.cpp, src/helpers.cpp, src/url_pattern_helpers.cpp (ten call sites), .jeffy/probes/build-flags/ (a new battery), BACKLOG.md (A10 deleted, one Settled class), PLAN.md (one Lesson and two rows re-recorded), JOURNAL.md.

Checkpoint: 92bb65973fbf115e4d7fd0a565a8af4f0226a472

Verification: The filed reproduction ran first and failed as filed - g++ -std=c++20 -O1 -I include -c src/ada.cpp exited 1 with 8 errors - and exits 0 after the fix, with -O0, -O2, -O3 and -Og still exiting 0 and clang++ still compiling at -O0, -O1 and -O2. That is A10's acceptance as written plus the levels it named as controls. Verify green through the installed quiet-verify.sh: "100% tests passed, 0 tests failed out of 353". Every battery under .jeffy/probes was run through the installed run-probe.sh and all twenty-one are green; check-claims.sh reports 21 checked, 0 mismatched, 0 errored, 0 skipped.

Class rather than instance. The compiler's error list named seven call sites, and that list is not the class: it is the sites GCC happened to fail on today, and url_pattern_helpers.cpp had a second identical call it did not report. The class is a predicate declared ada_really_inline passed by name to an algorithm, and its enumeration is a grep over the five algorithm forms crossed with the five always_inline predicates that reach them. That enumeration returned ten sites across five files; each now passes a lambda that calls the predicate directly, so the attribute stays in force for every direct call and only the address-taking is gone. The enumeration returns no site now, and it is recorded on the Settled classes line so it stays re-checkable. Three sites the grep also surfaced are outside the class and were left alone: checkers::is_digit and the file-local is_tabs_or_newline and is_forbidden_domain_code_point are plain inline functions, not always_inline.

The gap that let it ship is now instrumented. .jeffy/probes/build-flags compiles src/ada.cpp at -O0, -O1, -O2, -O3 and -Og under both documented compilers, and it is not named on an inventory row - it earns its place through its paths file, so any diff touching the files whose predicates it guards runs it. Against the tree at 6260a3c4 it reports 9/10 with g++ -O1 the single red cell, which is exactly the shape of a defect that ten green cells hid.

Contract preserved: no signature, behaviour or documented promise changes - a lambda calling a predicate is the same computation, and the 353-test suite plus every battery confirm it. Two batteries declare paths this diff touched, and their rows were re-recorded at this checkpoint.

Learnings: A compiler's error list is a sample of a class, not the class itself; enumerate by the property that causes the failure and re-run that enumeration after the fix. When a defect is invisible at every optimization level but one, the instrument that would have caught it is a matrix over the levels, and it belongs in the tree rather than in a run report.

Next: the ledger is at the severity floor with one Medium and four Lows, the map is fully swept, and no full audit this run has scored clean, so the final iteration is the closing full audit rather than a wrapup.

## iter 10/10 | e4890c79-161554 | 2026-08-31 | A3 | done

Task: A3 (Medium, runtime, documentation) - adaparse ignored -o/--output for a single URL, so the option docs/cli.md documents silently produced an empty file. This is the final iteration; A3 was worked rather than a wrapup written because it fits inside one iteration and closing it leaves the ledger at the severity floor for the next run.

Changed: tools/cli/adaparse.cpp (the single-URL path prints through adaparse_print, and adaparse_print stops re-formatting its own output), .jeffy/probes/adaparse-cli/ (ten new checks, claims and README), BACKLOG.md (A3 deleted), JOURNAL.md.

Checkpoint: e58707f945312a71ec0b7fb5fcabb61ecd7a79d3

Verification: The filed reproduction ran first and failed as filed - the file was zero bytes - and passes after: script -qec "adaparse -g href -o /tmp/ada_o.txt https://example.com/a" leaves the URL in the file. Verify green through the installed quiet-verify.sh: "100% tests passed, 0 tests failed out of 353". All twenty-one batteries green through the installed run-probe.sh. check-claims.sh was run for adaparse-cli, the only claims line this iteration changed, and reports 1 checked, 0 mismatched; the other twenty were checked whole at the previous checkpoint and each has just re-run green at its recorded total.

A crash was found and fixed inside this task rather than filed, because A3's acceptance could not pass without it. Routing to_string and to_diagram through adaparse_print aborted the process, and the cause was in adaparse_print rather than in the routing: it formatted its arguments and then passed the result to fmt as a format string again, so any brace in the data became a format specifier. That is reachable today without any of this run's changes - printf 'not a url {x}\n' | adaparse -o out.txt aborts with fmt::format_error "argument not found" at commit 92bb6597 and at 3fe77821 - and the piped path only avoided it because a URL's braces are percent-encoded before they are printed, while the "Invalid URL:" line echoes the raw input. The second format is now "{}", matching what the stdout branch already did. On the rubric that is a crash on realistic in-envelope input, and the piped file is an adversarial surface under this project's Operating envelope, so it is recorded here at that weight rather than as a footnote to a Medium.

The CLI battery grew from 32 checks to 42 and now pins both: each of the three single-URL output shapes written to a file, the same invocations without -o still reaching stdout, and a brace in the data surviving -o. Against commit 92bb6597 it reports 37/42, and against 3fe77821 it reports 23/42.

Contract preserved: no option, output format or diagnostic text changed; -o now reaches the paths its documentation always claimed, and without -o every path still prints to stdout, which the battery checks on both sides. The adaparse-cli row was re-recorded at this checkpoint.

Learnings: A lambda that formats and then re-formats is a latent crash wherever its data can contain a brace, and it hides until something routes user-controlled text through it. When a fix cannot pass its own acceptance without repairing a second defect on the same path, repair it and record it at its own severity rather than filing a task the same iteration would close.

Next: the run is out of budget. The ledger is at the severity floor with four Lows and one Proposed item, the map is fully swept, and no full audit this run has scored clean - so the next run opens with a fresh full audit, and convergence is one audit and one evaluator gate away.

## iter 11/12 | e4890c79-161554 | 2026-08-31 | WRAPUP | done

Task: The closing extension opened, and the convergence sequence it buys is not legally available to this run. This entry records why, tidies the ledger and hands off; the run ends here rather than spending iteration 12 reaching the same conclusion.

Changed: JOURNAL.md only. No BACKLOG.md item changed state and no Surface inventory row changed state, so by the stall check this iteration made no progress of the kind that check measures - which is what a WRAPUP is, and WRAPUP is one of the ceremony entries the check exempts. The previous primary entry is iteration 10's A3, which records a closed task, so no pair is formed.

Checkpoint: 96f5bef68604b5dbdccf1662d938fba47622e8ec

Verification: Verify green through the installed quiet-verify.sh: "100% tests passed, 0 tests failed out of 353". The working tree is clean apart from the metrics file the hook owns.

Why the window cannot be used. The closing rule admits exactly one convergence shape inside the extension: a clean full audit already on this run's record from before the window opened, then the gate, then the declaration. This run's record carries one AUDIT entry, iteration 1, and it scored correctness High, error handling High and documentation Medium and filed seven findings. There is no audit on the record scoring zero High and zero Medium in-envelope, and the window forbids making one - the hook ends the run the moment an AUDIT entry appears at an iteration inside it. The Definition of done therefore fails at its first condition, and every later condition being satisfied does not repair that: the map lists no unswept row, no High or Medium is open, and Verify is green, but a declaration standing on those alone would be a declaration the closing rule does not permit.

The evaluator gate was not invoked, and that is a decision rather than an omission. The gate is defined on the Definition of done path only, a PASS that does not declare in its own iteration does not carry forward, and the invocation cap is per run - so an invocation here would produce a verdict with no standing and spend the run's first invocation on it. The next run's declaration needs that invocation more than this run's record does. No .jeffy/evaluator artifact exists for this run and none should.

Ledger at handoff: four Lows, each carried with its severity written on its own line - A5, no build anywhere compiles the AVX-512 kernels, which is why A1 shipped; A6, no CI job builds adaparse, which is why A2 and A3 shipped; A4, is_top_project is tested at three places in CMakeLists.txt and defined nowhere, so the CPack block is dead; A7, include/ada_c.h ships without an extern "C" guard, filed Low because the header's own brief and the README's C example are the documented contract. One Proposed item awaits a decision: an xn-- label gets two verdicts depending on whether a sibling label is ASCII, and the corpus requires the accepting side while covering no invalid ACE label beside a non-ASCII one, so which side is wrong is a spec-interpretation call.

What the next run should expect. The map is fully swept at nineteen rows with one disclosed unreachable, twenty-two batteries are in the tree with their claims and their recorded failing states, and the ledger is at the severity floor. A fresh session opens with a full audit against that instrument; if it scores clean, the gate and the declaration follow inside the same run, which is two or three iterations rather than the ten this one needed to build the map.

Learnings: A run that files findings in its opening audit cannot converge in the same run unless a later full audit comes back clean, and the closing extension cannot supply that audit - so the shape of a first run on an unmapped project is map plus fix, with convergence falling to the second. Checking that precondition before the window opens is cheaper than discovering it inside.

Next: nothing. The run ends here; the loop state file is deleted and the run report follows.

## iter 1/10 | dc387909-183848 | 2026-08-31 | A5 | done

Task: A5 (Low, test, testing) - no build in the repository compiled the AVX-512 kernels, so include/ada/checkers-inl.h's IPv4 kernel and include/ada/url_ip-inl.h's IPv6 kernel were never compiled by CI, which is why A1 shipped.

Changed: .github/workflows/avx512-compile.yml (new), PLAN.md (Verify count filled from the wrapper's own green line, one Lesson), BACKLOG.md (A5 deleted), JOURNAL.md.

Checkpoint: 5ed97e583af252e456a09482d2ea6d864596ef9e

Verification: The filed reproduction ran first and failed as filed - grep -rn 'avx512\|march=' .github cmake CMakeLists.txt returned only cmake/toolchains-dev/riscv64-rvv.cmake, no AVX-512 build anywhere. The new job is a 14-cell matrix, two compilers by seven flag combinations, and every cell was executed locally rather than asserted: the two step scripts were extracted from the workflow file itself, the matrix expressions substituted, and each run through bash -e, so what was verified is the file that shipped rather than a retyped equivalent. All 28 steps pass on this tree. Verify green through the installed quiet-verify.sh: "100% tests passed, 0 tests failed out of 353". No battery under .jeffy/probes declares a path this diff touched, so none was owed a run; the Surface inventory has no stale row and none changed state.

The check is strong enough to fail, and the pre-A1 tree is where that was measured. Against commit e6754478, extracted with git archive into a scratch tree so no repository state moved, the same 28 steps report 26/28: the `-mavx512bw -mavx512vl -mavx512vbmi -mavx512vbmi2` compile fails under both g++ and clang++ with the always_inline BMI errors that were A1. Exactly one of the seven flag combinations catches it, and that is the finding inside the finding: -march=icelake-server, -march=sapphirerapids and -march=znver4 all imply BMI and BMI2, so a matrix built only from CPU names would have compiled A1 clean. The explicit -mavx512* combination that stops short of -mbmi/-mbmi2 is the one cell that reproduces the class, and it is in the matrix on purpose.

A compile that no longer reaches the kernels would pass vacuously, which is the failure mode this row's own PLAN.md text warns about - a parameter whose value changes nothing reads exactly like a parameter that works. Each cell therefore asserts which kernels its flags select before compiling anything: it preprocesses a one-line translation unit including ada/url_ip-inl.h, reads ADA_AVX512, ADA_AVX512_IPV6 and __AVX512VBMI2__ out of the -dM dump, and compares them against the ipv4/ipv6 expectations written on that matrix row. Three cells expect no IPv4 kernel and four expect both, which is the shape g++ actually reports here; a flag set that quietly stopped selecting a kernel fails the assertion rather than the compile.

Compile only, and that is a deliberate limit rather than an oversight: GitHub's hosted runners are not guaranteed to have an AVX-512 CPU, so executing the kernels there would be a coin flip presented as a check. The kernels remain unexecuted everywhere - this host cannot run them either - and the Surface inventory row stays [~] unreachable with its reason unchanged. No journal entry may claim they were green, and this one does not.

Contract preserved: no source file, header, build option or public behaviour changed. The workflow adds a job and nothing else, and the Verify command is untouched, so PLAN.md's Environment fingerprint still describes what ctest grades - the new job is outside it.

Learnings: An -march naming a real AVX-512 CPU implies BMI and BMI2, so a matrix built from CPU names alone cannot expose a kernel that reaches a BMI intrinsic its own guard does not imply; the explicit feature-flag combination without -mbmi/-mbmi2 is the cell that does. When a CI job is the deliverable, run its own step scripts extracted from the YAML rather than a hand-written equivalent, and run them against the tree the defect shipped on to prove the job would have caught it.

Next: A6 is the top open item - no CI job builds adaparse, which is why A2 and A3 shipped. Three Lows remain and the map is fully swept, so the ledger reaches the replenishment threshold after A6, and a full audit there both replenishes and supplies the clean audit this run's convergence needs.

## iter 2/10 | dc387909-183848 | 2026-08-31 | A6 | done

Task: A6 (Low, test, testing) - ADA_TOOLS defaults OFF and no workflow turned it on, so adaparse, the CLI documented in README.md and docs/cli.md, was never built or run by CI at all, which is why A2 and A3 shipped. The iteration also repaired the verify gate's own count, which the Stop hook flagged at the previous checkpoint.

Changed: .github/workflows/adaparse-cli.yml (new), PLAN.md (Verify command, Verify summary pattern, two Lessons), BACKLOG.md (A6 deleted), JOURNAL.md.

Checkpoint: a464f884a787592c31e733a3c14b51db01974ab7

Verification: The filed reproduction ran first and failed as filed - grep -rn 'ADA_TOOLS' .github/workflows returned only ubuntu.yml's -DADA_TOOLS=OFF. The new job's three step scripts were extracted from the workflow YAML and run against a clean checkout produced with git archive, so what was verified is the file that shipped on the tree CI would actually see: configure, build, and six driven URLs, all six green. Verify green through the installed quiet-verify.sh: "Total Tests: 353". No battery under .jeffy/probes declares a path this diff touched; the Surface inventory has no stale row and none changed state.

The gate was measuring the wrong number, and that is the first half of this entry. PLAN.md's Verify count cell holds the total the wrapper computes, and the wrapper computes it as the first integer on the line matching the Verify summary pattern. The pattern was [0-9]+% tests passed, which matches ctest's "100% tests passed, 0 tests failed out of 353" - whose first integer is 100. The wrapper had recorded count 100 in .jeffy/metrics/verify-last.json against a 353-test suite, and the hook was right to refuse the 353 I typed. Writing 100 into the cell would have satisfied the hook while recording a percentage as a suite size, which is the exact failure the cell exists to prevent, so the fix went to the measurement instead: the Verify command now ends with `ctest --test-dir build -N`, which lists without running and prints "Total Tests: 353", and the pattern points at ^Total Tests: [0-9]+. The wrapper now records 353 and the cell matches it. The appended command is joined with && so a red suite still short-circuits before it and the chain's status stays the suite's; -N grades nothing, so the Oracle class is unchanged.

The CLI job drives both input paths because they are different code, and the pre-fix trees prove each half. adaparse reads stdin whenever stdin is not a tty, so under a CI shell it ignores argv entirely; the argv path only exists behind a pty, supplied here by script(1). Against the tree at 3fe77821, before A2, the job reports 2/6: all three piped checks return the right text with status 1, which is A2 exactly - piped_file's EXIT_SUCCESS read as a false branch. Against 92bb6597, before A3, it reports 5/6: the -o check gets an empty file, which is A3 exactly. A piped-only check would have caught A2 and missed A3; a pty-only check the reverse. One trap paid for on the way: a pty appends a carriage return to every line, so the checks strip it before comparing, and the earlier eyeball comparison that looked equal was not.

Contract preserved: no source file, header, build option or public behaviour changed. Both changes are additive - one workflow file, and a listing command appended to the gate that runs no tests. PLAN.md's Environment fingerprint still holds: ADA_TOOLS defaults OFF, so the Verify command still neither builds nor tests adaparse, and the new job is outside it.

Learnings: When a wrapper derives a number from a pattern, check what the pattern actually selects before trusting either side of the comparison - a percentage and a total sit on the same ctest line, and the cheap resolution of typing the number the hook wanted would have written the wrong quantity into a governance file. A CI job for a tool with two input paths needs a case on each: the two defects this job is meant to have caught fail on different halves of it, and either half alone certifies the tree the other one broke.

Next: A4 is the top open item - is_top_project is tested at three places in CMakeLists.txt and defined nowhere, so the CPack block is dead. A7 follows, and with the ledger empty after it the full audit lands with budget for the gate and the declaration.

## iter 3/10 | dc387909-183848 | 2026-08-31 | A4 | done

Task: A4 (Low, build-ci, developer experience) - CMakeLists.txt tested is_top_project at three places and defined it nowhere, so an undefined variable made every one of them false: two status messages never printed and the CPack block never ran, leaving cpack with no configuration to read since the initial commit.

Changed: CMakeLists.txt (is_top_project defined; CPACK_SOURCE_IGNORE_FILES set), .jeffy/probes/packaging/ (six checks for the source-package channel, claims and README), PLAN.md (one Lesson), BACKLOG.md (A4 deleted), JOURNAL.md.

Checkpoint: d5bef85cd81bc5b76a06d423ac4b8d952cf9f42a

Verification: The filed reproduction ran first and failed as filed - cmake -S . -B build-cpack -DADA_TESTING=OFF exits 0 but build-cpack/CPackSourceConfig.cmake is absent - and the same acceptance passes after. The second half of the acceptance was checked by building the package rather than by reading the config: cpack --config CPackSourceConfig.cmake -G TGZ produces ada-4.0.0-Source.tar.gz, 240 entries, holding no PLAN.md, BACKLOG.md, JOURNAL file, .jeffy path, build directory or .git. Verify green through the installed quiet-verify.sh: "Total Tests: 353", and build/CPackSourceConfig.cmake now exists in the gate's own build directory, so the change is live where the suite runs rather than only in a scratch configure. check-claims.sh reports 21 checked, 0 mismatched, 0 errored, 0 skipped.

is_top_project is defined as CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR rather than PROJECT_IS_TOP_LEVEL, because cmake_minimum_required is 3.16 and that variable arrived in 3.21. An embedder still gets neither the status messages nor the CPack targets, which is what the three guards were always for.

Turning the block on creates an artifact-producing channel, and that is the part of this task worth more than the dead code it revived. The Method requires each such channel be checked for the loop's own state, and CPack's default ignore list covers none of it. A first attempt used list(APPEND ...), which is wrong in a way that would have passed every check I had written: the variable is undefined until CPack.cmake supplies its default, so appending to it defines it early and silently discards the VCS defaults instead of extending them. It is now a single set() that repeats those defaults beside the additions.

The ignore list is load-bearing and was measured, not assumed. A control tree carrying the is_top_project definition alone, with no ignore list, packages 227 entries of the configured build directory, 104 of .jeffy/probes, .jeffy/metrics and the three state files. The battery that owns CMakeLists.txt was extended to keep that verification rather than leave it in this entry: six checks covering the config, the build, the two negative arms and one positive arm, that last one because an ignore list excluding everything would satisfy both negative checks. The battery is 20/20 to 26/26 and both README figures were re-measured, since neither survived the change. A tree with include/ada/url_ip-inl.h deleted now reports 15/26 rather than 9/20, and its source-package checks all pass - a missing header breaks the build, not the configure that writes CPackSourceConfig.cmake - so the new arm needed a discriminating state of its own: a tree defining is_top_project with no ignore list reports 25/26 with the loop-state check returning 112.

Contract preserved: no source file, header or public behaviour changed, and no existing CMake option changed meaning. The two revived status messages print only for a top-level build with testing, benchmarks or tools enabled, which is the audience the guard names. The packaging battery was re-run through the installed run-probe.sh and its inventory row is re-recorded at this checkpoint.

Learnings: An undefined CMake variable in if() is silently false, so a guard nobody defined disables its block without any diagnostic - git log -S is the way to tell a removed definition from one that never existed. list(APPEND) against a variable whose default the includer supplies later is a silent replacement of that default, not an extension of it. When a fix opens a publishing channel, the check that the channel is clean belongs in the battery that owns the file, and both of the battery's failing-state figures have to be re-measured rather than adjusted by arithmetic.

Next: A7 is the last open item - include/ada_c.h ships without an extern "C" guard. With the ledger empty after it, the full audit lands with the gate and the declaration still inside budget.

## iter 4/10 | dc387909-183848 | 2026-08-31 | A7 | done

Task: A7 (Low, docs, developer experience) - include/ada_c.h is installed as a public header but carried no extern "C" guard, so a C++ translation unit including it got undefined references at link time; ada's own tests/ada_c.cpp wrapped the include to work around it.

Changed: include/ada_c.h (guard added, file brief corrected), tests/ada_c.cpp (workaround removed), PLAN.md (one Lesson), BACKLOG.md (A7 deleted, A11 filed), JOURNAL.md.

Checkpoint: 5e61bc0b7bdbb1a04d04099ca60ff5a9ba8ff152

Verification: The filed reproduction ran first and failed as filed - a C++ file including ada_c.h and calling ada_parse fails to link against build/src/libada.a with undefined reference to ada_parse(char const*, unsigned long), while the archive exports the unmangled T ada_parse - and the same file links and runs after. The C path README.md documents was checked on both sides and still works: a C11 program compiled with cc against the same archive prints the href. Verify green through the installed quiet-verify.sh: "Total Tests: 353". The c-api battery reports 60003/60003 and packaging 26/26 through the installed run-probe.sh; both declare include/ada_c.h and both rows are re-recorded at this checkpoint.

The guard is safe because the definitions already had C linkage: src/ada_c.cpp wraps its whole body in extern "C", which is why C consumers link today and C++ ones did not. Adding the guard changes no exported symbol - it changes what a C++ consumer's compiler emits at the call site, from a mangled name to the one the library already exports.

The regression test is the project's own suite rather than a new probe. tests/ada_c.cpp is a C++ translation unit that includes ada_c.h and links against the library, which is exactly A7's acceptance, so removing its extern "C" wrapper turns the ada_c target into the guard's permanent check. That was confirmed by removing the guard from the header against the warm build tree and rebuilding that one target: it fails with undefined reference to ada_parse(char const*, unsigned long), ada_is_valid(void*) and ada_free(void*). The header was copied aside first and restored after, so the fix under test was never checked out over.

Making the header C++-includable made one cheap check possible that was not before, and it found something. Compiling a translation unit that includes src/ada.cpp and then ada_c.h reports conflicting declarations for ada_string and ada_owned_string: src/ada_c.cpp never includes the public header and re-declares every C type and function itself, the header using anonymous typedefs where the implementation uses named structs. Nothing is wrong today - the layouts were measured and agree field for field, and the single-header path README.md documents compiles ada.cpp and the C program as separate translation units, so the two declaration sets are never in one TU - so it is filed as A11 at Low rather than Medium, with that rationale on its line. Two earlier attempts at this cross-check failed for an unrelated reason worth recording: src/ada_c.cpp does not compile standalone at all, being a fragment of the src/ada.cpp translation unit.

Contract preserved: no function signature, no exported symbol and no documented behaviour changed. The file brief no longer says "This is a C file, not C++", because that sentence is what the guard just made false; the C interface it describes is unchanged.

Learnings: A public C header without an extern "C" guard links from C and fails from C++, and the cheapest regression test is usually an existing C++ test target that includes it bare rather than a new probe - the suite then pins the guard for free. When a header becomes includable from a language it was not, run the cross-check that includability enables; here it surfaced a duplicated declaration set that no compiler had ever compared.

Next: the ledger holds one Low, A11, filed this iteration. The map is fully swept and no full audit this run has scored clean, so the next iteration is the closing full audit, leaving the gate and the declaration inside budget.

## iter 5/10 | dc387909-183848 | 2026-08-31 | AUDIT | audit

Task: The closing full audit. The ledger was at the severity floor, the map fully swept and no full audit on this run's record, so this iteration rescored every applicable dimension with fresh evidence rather than working the one open Low. Closeout has not begun: the audit found a Medium.

Changed: BACKLOG.md (A12 filed), JOURNAL.md. No file outside the state files changed and no Surface inventory row changed state, which is what an AUDIT iteration is; the previous primary entry closed A7, so no stall pair is formed.

Checkpoint: 0fff51dbd76506040ab064199f4a65b8efbff527

Verification: Fresh evidence is the whole instrument executed, not re-read. check-claims.sh reports 21 checked, 0 mismatched, 0 errored, 0 skipped, which is every battery run - among them url-class 80000, aggregator-setters 240000, percent-encoding 62732, c-api 60003, url-components 43378, parse-fast-paths 21569, url-search-params 20027 and top-level-api 20014. Verify green through the installed quiet-verify.sh: "Total Tests: 353". No inventory row is stale: every battery's declared paths were diffed against the commit its row records, and all nineteen come back current. Testing was not scored before running modules in isolation, as the Method requires: ada_c alone passes 17, url_search_params alone 37, url_components alone 1, and a single case run entirely alone passes; no order dependence or leaked state appeared. One trap worth naming - ctest exits 0 when a -R filter matches nothing, so the first isolation attempt read as green while running no tests at all, and the counts above are from filters confirmed to select cases.

Standing claims re-derived rather than re-read. A8's Declined premise holds: the corpus still maps xn--, xn--0.pt and xn--a.pt to themselves, so the finding's premise remains false. Both Settled classes hold - the always_inline predicate enumeration returns no site, and the BMI enumeration returns four call sites, each checked to sit inside a __BMI__ or __BMI2__ guard rather than merely counted. The Environment fingerprint's exclusion command returns exactly the eight files that line names, and the Oracle class still describes what ctest grades.

The audit is not clean, and the finding is in a channel the previous audit's enumeration missed. Enumerating artifact-producing channels by command rather than by recall turns up five. Four are clean and were checked: the CMake install and the singleheader amalgamation through the packaging battery, the cpack source package through the six checks added at iteration 3, and the GitHub release assets, which tools/release/create_release.py uploads as four named singleheader paths and nothing else. The fifth is the one nothing in the tree controls. There is no .gitattributes, so git archive HEAD - the exact mechanism behind the "Source code (tar.gz)" asset GitHub attaches to every release, and release_create.yml creates releases - carries PLAN.md, BACKLOG.md, JOURNAL.md and 109 entries under .jeffy/. That is filed as A12 at Medium with its Consequence stated, which is the severity the Method fixes for a published artifact carrying the loop's state; it is not discounted for having been caused by the loop's own commits, because the rule exists for exactly that case.

Scores, claiming the nineteen swept rows and not the one disclosed unreachable row: correctness None, security None, error handling None, architecture None, dependency hygiene None - CPM pins googletest 1.15.2, benchmark 1.9.0, simdutf 7.3.2 and codspeed-cpp 2.0.0 to explicit versions - observability None, UX and accessibility None on the adaparse surface now that its exit paths are driven by CI. Code quality Low, carrying A11. Testing Low: the suite still executes no AVX-512 kernel anywhere, which the inventory discloses as unreachable on this host rather than hides, and the two CI jobs added this run are the first coverage the kernels and the CLI have had. Developer experience Medium, carrying A12. Performance was not scored: no benchmark was run this iteration and no performance finding was reproduced, so there is nothing to score it from.

Learnings: Enumerate publishing channels by the mechanism that produces them, not by the files the project chose to name - four channels the project controls were all clean, and the defect sat in the one it never wrote any configuration for. A repository that commits agent state has a source-archive channel by default, and the absence of a config file is what makes it invisible to a search for one.

Next: A12 is the single open Medium and the top of the queue. Fixing it, then the evaluator gate, then the declaration fits the remaining budget; A11 rides to the declaration as a carried Low.

## iter 6/10 | dc387909-183848 | 2026-08-31 | A12 | done

Task: A12 (Medium, build-ci, developer experience) - the repository carried no .gitattributes, so nothing marked the loop state export-ignore and git archive, the mechanism behind the "Source code" assets GitHub attaches to every release, carried PLAN.md, BACKLOG.md, JOURNAL.md and 109 entries under .jeffy/ into every published source archive.

Changed: .gitattributes (new), .jeffy/probes/source-archive/ (a new battery with paths, claims and README), PLAN.md (one Lesson), BACKLOG.md (A12 deleted), JOURNAL.md.

Checkpoint: b78de46087c05449b6b49795b97b24edde2f6584

Verification: The filed reproduction ran first and failed as filed - git archive HEAD listed 112 loop-state entries and git check-attr reported export-ignore unspecified for every one of the four state files. After the fix the same archive of the staged tree, which is byte for byte what this checkpoint commits, lists zero of them while still carrying 62 entries under src/, include/ and CMakeLists.txt. The totals reconcile exactly: 350 entries before, 239 after, and 350 plus the one new .gitattributes minus the 112 removed is 239, so nothing left the archive that was not the loop's own. Verify green through the installed quiet-verify.sh: "Total Tests: 353". check-claims.sh reports 22 checked, 0 mismatched, 0 errored, 0 skipped.

The rule is scoped by path and was checked on both sides. src/ada.cpp and CMakeLists.txt remain unspecified, and the archive still lists src/parser.cpp, include/ada.h and CMakeLists.txt by name; a rule broad enough to drop the library would have satisfied the negative check just as well, which is why the control is in the battery rather than only in this entry.

The instrument was nearly a fake, and that is the part of this iteration worth keeping. The new battery asks git for the export-ignore attribute rather than archiving HEAD, so it reflects the working tree and is not red for the length of the iteration that adds the rule. Measuring its failing state by deleting .gitattributes reported 6/6 - still green with the rule gone - because git check-attr falls back to the index when the working-tree copy is missing, and the file was already staged. The real failing state was taken in a scratch git repository that never carried the file, where the battery reports 1/6 with only the control passing. Had the first measurement been trusted, the battery would have been recorded as verified while being incapable of failing.

One check-attr result is worth stating precisely rather than smoothing over: .jeffy/probes/packaging/run.sh reports unspecified, because the attribute is set on the .jeffy directory entry and check-attr does not report it as inherited by files beneath. The archive is the authority there, and it drops the whole directory, which the entry counts above confirm; the battery therefore checks .jeffy itself rather than a file inside it.

Contract preserved: no source file, header, build option or public behaviour changed. .gitattributes affects git archive alone, so the CMake install, the singleheader amalgamation, the cpack source package and the four named release assets are all untouched, and the packaging battery still reports 26/26 over them. No battery declares a path this diff touched other than the one added here.

Learnings: A probe that reads git attributes must be reddened in a repository that never carried the attributes file, because check-attr falls back to the index and a staged file keeps the probe green after the working copy is deleted. When a fix removes files from an artifact, reconcile the before and after totals arithmetically rather than checking only that the unwanted names are gone - the same absence is produced by a rule that removed far more than intended.

Next: the ledger holds one carried Low, A11, and the closing audit's only Medium is closed. The next iteration brings the standing claims current and runs the evaluator gate, which is invocation 1 for this run.

## iter 7/10 | dc387909-183848 | 2026-08-31 | EVALUATOR | converged

Task: The convergence sequence. Standing claims were brought current, the adversarial evaluator gate was invoked as invocation 1 of this run, it returned PASS, and the closing conditions hold, so this iteration declares.

Changed: .jeffy/evaluator/dc387909-183848-1.md (the gate's artifact), BACKLOG.md (three gate observations filed as carried Lows, Converged line appended), JOURNAL.md. No file outside the state files and the gate artifact changed and no Surface inventory row changed state, which is what an EVALUATOR iteration is; the previous primary entry closed A12, so no stall pair is formed.

Checkpoint: 52db4790a67fc38ca21ae419f24bc450ea6c2380

Verification: Evaluator: PASS - invocation 1, artifact .jeffy/evaluator/dc387909-183848-1.md, which re-ran the verify gate, re-executed every closed task's acceptance, reproduced A12 on the base commit and confirmed it fixed at HEAD, extracted the published archive and built it end to end to 353 passing tests, and re-scored every finding against the rubric. Verify green through the installed quiet-verify.sh this iteration: "Total Tests: 353". check-claims.sh reports 22 checked, 0 mismatched, 0 errored, 0 skipped, and the Verify count cell equals the total the wrapper reports.

Standing claims were made current before the invocation rather than after, so the gate did not spend itself on bookkeeping the run had already outdated. No Surface inventory row is stale: every battery's declared paths were diffed against the commit its row records and all nineteen come back current, with one row disclosed unreachable and none unswept. A8's Declined premise still holds, the corpus mapping xn--, xn--0.pt and xn--a.pt to themselves. Both Settled classes hold, the always_inline enumeration returning no site and the BMI enumeration returning its four guarded call sites. The Oracle class and Environment fingerprint were re-read and the fingerprint's exclusion command still returns exactly the eight files it names. PLAN.md names no finding ID as carried or blocked, so no reference can dangle.

The gate confirmed the run's own reproductions independently, which is the part worth recording. It re-derived A12's base failure at 111 loop-state entries against 112 measured here - the difference is the three files this run added, which do not exist on the base commit - and then went further than the acceptance by extracting the published archive and building it, which the run had not done. It also verified that A5's workflow is strong enough to fail, reporting 28/28 at HEAD and 26/28 on the pre-A1 tree, matching this run's own measurement.

Carried Lows, each with its severity on its own ledger line: A11, src/ada_c.cpp re-declares the public C types and functions independently of ada_c.h, which it never includes, so the two can diverge with no diagnostic while today agreeing field for field. A13, the cpack source package this run turned on carries .claude/jeffy-loop.local.md because the ignore list and the packaging battery's check both name only the four other state paths. A14, the source-archive battery asserts the export-ignore attribute rather than the archive that attribute shapes. A15, A11's line names two of the five conflicting declarations the cross-TU compile actually reports. A13, A14 and A15 are the gate's three observations, filed rather than fixed: a fix after a PASS invalidates that PASS and spends an invocation the declaration needs, so they are the next run's first work.

Learnings: Bring every standing claim current in the same iteration that invokes the gate, before the invocation rather than after - the gate consumes them exactly as the declaration does, and an invocation spent on a stale row is one the declaration then lacks. A gate observation is a finding for the next run, not a defect to repair before declaring; the sequence that repairs it loses the PASS it was trying to protect.

Next: nothing. The run converged at this iteration; the loop state file is deleted and the run report follows.
