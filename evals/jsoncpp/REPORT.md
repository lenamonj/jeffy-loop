# Jeffy eval: open-source-parsers/jsoncpp

**Target**: [open-source-parsers/jsoncpp](https://github.com/open-source-parsers/jsoncpp) (8,876 stars, verified via `gh api repos/open-source-parsers/jsoncpp --jq '.stargazers_count'` on 2026-07-30) at `60de77f915ab08499032d6e5a63e05e974f85d01`, upstream master at the time of the run. Public domain, or MIT in jurisdictions that do not recognise it. C++, in a local clone; the loop's work was never pushed anywhere. jsoncpp is the long-standing C++ JSON parser, vendored into a very large number of desktop and embedded projects.

**This is a full `/jeffy` loop run that reached machine-checked convergence, in a single run of ten iterations.** **7 findings filed and closed (2 High, 2 Medium, 3 Low)** across a diff of 11 files, +299/-77, of which the shipped-code change is **5 files, +41/-40**. Converged at `5664f81ea214380e7c116181dd370c89d031b555` on 2026-07-30: empty ledger, all **16 surface-inventory rows swept**, the verify command re-run fresh for this receipt at 3/3 suites green, and the adversarial evaluator's PASS on record.

This is the first C++ target and the fifth language in the set.

## The headline finding, reproduced independently for this receipt

**jsoncpp's own documented secure-memory build mode does not compile on MSVC.** Building pristine upstream `60de77f` with `JSONCPP_USE_SECURE_MEMORY=1` fails:

```
include\json\allocator.h(47,5): error C3861: 'RtlSecureZeroMemory': identifier not found
```

Three times, from a clean configure. That is JC-1, and it means every Windows user who followed the project's own instructions for handling sensitive data in JSON either never got a build, or silently was not getting secure memory. The fix makes the secure build compile and run all 132 unit tests, and additionally corrects the wipe itself, which did not cover the full allocated block.

## What the loop found

- **JC-1 (High, security)** - `SecureAllocator` did not compile under `JSONCPP_USE_SECURE_MEMORY=1` on MSVC, and its zeroing did not cover the whole block. Closed with the secure build going from `error C3861` to compiling with 132 tests passing, and the wipe widened to the full allocation.
- **JC-7 (High, security)** - **found by the adversarial evaluator, not by the loop.** After JC-1 fixed the library, `jsontestrunner` still failed to compile under the same flag, so the secure configuration remained unbuildable as a whole. One-line fix at `src/jsontestrunner/main.cpp:331`, `std::string` to `Json::String`, type-identical in default builds. See the note below, because this is the most instructive thing in the run.
- **JC-2 (Medium, correctness)** - `string_view` detection ignored `_MSVC_LANG`, so MSVC consumers building at `/std:c++17` without `/Zc:__cplusplus` silently got a **different public API** from GCC and Clang users. A compile-only probe of `isMember(string_view)` and `operator[](string_view)` went from `error C2665` to compiling.
- **JC-3 (Medium, testing)** - nothing in CI ever built the secure-memory configuration, which is why JC-1 survived. `cmake.yml` gained a `cmake-secure-memory` job across three operating systems at C++17. This is the finding that stops JC-1 recurring.
- **JC-6 (Low, code quality)** - `CZString`'s implicit copy-assignment shallow-copied an owning pointer, a latent double free. Explicitly deleted after a grep proved zero call sites, and a misleading comment in `value.h` corrected.
- **JC-4 (Low, dependency hygiene)** - stale `appveyor.yml` removed, with a grep confirming nothing referenced it.
- **JC-5 (Low, testing)** - swept the Meson build row, the last unswept inventory row, by installing Meson 1.11.2 and running setup, compile and test to green on MSVC rather than inferring it.

## The evaluator earned the run

Iteration 9 is the one worth reading. The loop had an empty ledger, all sixteen inventory rows swept, and a clean closing audit. It invoked the adversarial evaluator expecting to declare convergence. The evaluator returned **REJECT**, and the journal records it plainly:

> Evaluator gate (invocation 1 of 2) ahead of convergence. Result: REJECT - convergence not declared.

What it caught was that JC-1, the run's own headline fix, was **incomplete**: the library compiled under secure memory but the test runner did not, so the configuration as a whole was still broken. That became JC-7, filed at High, fixed in iteration 10, and the run converged on its final budgeted iteration.

Two things follow. The gate works, and it works precisely where self-assessment is weakest: on the completeness of the loop's own fix, in the code the loop had just written. And it only worked here because exactly one iteration remained. Had JC-7 needed two, this run would have ended out of budget holding an unanswered REJECT, which is how a documented seven of fourteen runs in the two longest projects in this set have ended.

## Honest caveats

- **The two Highs are the same defect in two places**, and neither is a parsing bug. They are build-configuration defects in an opt-in mode. That mode is a security feature and the receipt treats it as security, but a reader should know the JSON parser itself was not found to mis-parse anything.
- **The crash class was deliberately out of scope.** OSS-Fuzz has continuously fuzzed jsoncpp for years and `fuzz.cpp` is checked into the repo, so the run was pointed at semantics and API contracts rather than at segfaults. A finding of "no crashes" would have been unearned.
- **JC-3 changes CI configuration, not shipped code.** It is filed Medium on the argument that the absence of the job is what let JC-1 ship, which is a defensible call but a call.
- **Seven findings from a 16-row surface in one run is a thin yield** compared to fasthttp's 31. jsoncpp is a smaller, older, heavily fuzzed library, and the run says so rather than inflating severities to compensate.
- **The `- [~]` platform-bound row state did not exist for this run.** Every row here was reachable on the Windows host, so the question never arose.

## Independently re-verified for this receipt

- Verify gate re-run from the converged tree: `cmake --build build --config Debug` then `ctest`, 3/3 suites passed, 16.2s.
- The headline defect reproduced from scratch on a pristine clone at `60de77f` with the exact `error C3861` output quoted above.
- `fixes.patch` proven to apply cleanly to pristine `60de77f` with `git apply --check`.
- Convergence conditions confirmed at the tree: `Converged: 5664f81`, 16 of 16 inventory rows swept, `Now`/`Next`/`Later` empty, `Evaluator: PASS` recorded.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative above; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).

**Status**: the work lives in this eval's `fixes.patch` (+299/-77 across 11 files, of which shipped code is 5 files +41/-40, applies to pristine `60de77f`) and `journal.md` (all ten entries of the single run, as written).

**Upstream**: **MERGED 2026-08-20** as [open-source-parsers/jsoncpp#1709](https://github.com/open-source-parsers/jsoncpp/pull/1709) - the patch went in as written, 4 files, +32/-31, carrying JC-1 and JC-7 together with the `CZString` move-assignment fix, and closing [#1399](https://github.com/open-source-parsers/jsoncpp/issues/1399), open since March 2022. That issue reported both the portability problem and, in its own words, that "the unit tests won't build" - which is JC-7 exactly, four years before this run found it.

Two things were settled by experiment while preparing the PR rather than by reading the journal, and both changed what got submitted.

The `CZString` move-assignment fix looked like scope creep from JC-1: it releases a key with `releasePrefixedStringValue` where the key came from `duplicateStringValue` and carries no length prefix. Reverting it and rebuilding answered the question - the secure configuration compiles and then **`jsoncpp_test (SEGFAULT)`**. It is load-bearing, not incidental, and the layered failure became the strongest part of the PR: the build fails, then once it builds the test runner fails, then once everything builds the suite crashes. Three defects stacked in one configuration nothing ever exercised.

The under-wipe claim was cut back rather than repeated. The old fill zeroed `n` bytes rather than `n * sizeof(T)`, which reads like live data exposure. It is not: `Json::String` is `SecureAllocator<char>`, so `sizeof(T)` is 1 and the two expressions are identical. It is a genuine latent defect for any wider `T` through the public `Json::Allocator<T>` alias, and the PR says exactly that. Leading with the stronger version would have been overclaiming.

The default build was verified unaffected, 3/3 suites green, before anything was submitted.
