# Jeffy eval: ada-url/ada

The WHATWG URL parser that ships inside Node.js - Node 24's URL
implementation is ada - written in C++ with hand-rolled AVX-512 kernels and
a WPT-derived conformance corpus. Run 2026-08-31 as wave 5 of the
merged-PR campaign (COHORT-WAVE5.md). **2 runs, 18 iterations, converged**
in run 2 at `52db4790a67fc38ca21ae419f24bc450ea6c2380`, within a
**pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `e67544784e8df244a7d999f7423bc8680b9ccdca` (main; upstream CI at pin 48 success + 1 failure that is CodSpeed benchmarking, not a test leg, declared before launch) |
| Findings closed | **10** - 4 High, 2 Medium, 4 Low |
| Shipped-code change | 16 files, **+305 / -40** |
| Surface inventory | **19 of 19 rows swept** |
| Ledger at convergence | 4 Lows carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | 353 CTest tests green (~3.4 s) |

## What the loop found

- **`A1` (High)** - the AVX-512 IPv6 host kernel in
  `include/ada/url_ip-inl.h` called BMI1 and BMI2 intrinsics under a guard
  that names only AVX-512 feature macros, so a build enabling exactly the
  features the file's own comment calls for failed to compile with
  "inlining failed in call to always_inline" at three sites. The IPv4
  kernel in `include/ada/checkers-inl.h` already carried the correct
  guard; the later IPv6 kernel did not follow it.
- **`A2` (High)** - `tools/cli/adaparse.cpp` tested `piped_file`'s int
  return as a boolean, so its `EXIT_SUCCESS` (0) landed in the false
  branch and every non-tty invocation of the CLI exited 1 no matter what
  it had done.
- **`A9` (High)** - `ada::url` reported `get_components().host_end` one
  short of the documented one-past-the-host position, subtracting one in
  the no-credentials branch of `include/ada/url-inl.h`, so a consumer
  slicing the href by `[host_start, host_end)` got a truncated host. Both
  `ada::url_aggregator` and the components struct's own documentation
  diagram disagree with it, and `tests/url_components.cpp` never mentioned
  `host_end`.
- **`A10` (High)** - the library did not compile with g++ at `-O1`: ten
  call sites in `src/url.cpp`, `src/url_aggregator.cpp`,
  `src/url_pattern_helpers.cpp` and `src/unicode.cpp` passed an
  `ada_really_inline` predicate by name into a `std::ranges` algorithm,
  and GCC refuses to inline an always_inline function reached through
  `std::__invoke`. `-O0`, `-O2`, `-O3` and `-Og` all compile and clang
  compiles at every level, which is why no CI job ever met it; a distro or
  consumer building at `-O1` got a hard failure.
- **`A3` (Medium)** - adaparse ignored `-o`/`--output` for a single URL,
  so the option `docs/cli.md` documents silently produced an empty file.
  Closing it also surfaced a pre-existing crash: `adaparse_print` passed
  already-formatted data back to fmt as a format string, so a brace in a
  piped non-URL line aborted the process with `fmt::format_error`.
- **`A12` (Medium)** - the repository carried no `.gitattributes`, so
  `git archive`, the mechanism behind the "Source code" assets GitHub
  attaches to every release, carried the loop's own state files into every
  published source archive. Filed at the severity the method fixes for a
  published artifact carrying loop state, not discounted for having been
  caused by the loop's own commits.

## A withdrawn High

A8 was filed High in iteration 5 of run 1: the claim was that `to_ascii`
in `src/ada_idna.cpp` returns early for any ASCII domain, so an `xn--`
label in a pure-ASCII domain never reaches the punycode validation the
same file implements, with Node 24.17.0 rejecting a family of hostnames
this tree accepts. The fix was written, and the tree's own gate refused
it: the patched build went red on 9 of 353 tests, among them
`wpt_url_tests.idna_test_v2_to_ascii` asserting that `xn--ab-j1t` must map
to itself. The investigation that followed showed the finding's premise
was false. Node is the wrong oracle here - of the 960 pure-ASCII domains
carrying an `xn--` label in `tests/wpt/IdnaTestV2.json`, Node rejects 761
the corpus expects accepted - and the corpus names the exact inputs the
finding was built on, `xn--a.pt`, `xn--0.pt` and `xn--`, all with
themselves as the expected output. The ASCII short-circuit is required
behaviour. A8 was withdrawn to Declined in iteration 6, the fix reverted,
and the residual spec-interpretation question filed as Proposed rather
than at a severity the evidence cannot support. Published here as
evidence the run's own controls reject bad findings: the conformance
suite, not the reviewer, is what killed it.

## AI usage disclosure

ada-url ships `AI_USAGE_POLICY.md`, which requires a human in the loop
for contributions: a person who has read and reviewed the work, is
accountable for it, and can answer questions during review.

`A9` was filed upstream as [PR #1244](https://github.com/ada-url/ada/pull/1244)
under that policy. The finding and its patch were reviewed by a person
before filing, the pull request states its provenance, and the review
questions were answerable by the person who filed it. It was **merged on
2026-09-01**, about forty minutes after it was opened, by a project
maintainer. Nothing else from this run was sent upstream.

## Environment

WSL2 x86_64, CMake + CTest. Engine 1.20.0 on Claude Code 2.1.232, model
`opus[1m]`. Oracle sabotage-proven before launch: `percent_decode` made
to return its input verbatim reddened **10 of 353 tests** after a forced
rebuild, with 100% restored on revert-and-rebuild. Flake gate 10/10
green.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
