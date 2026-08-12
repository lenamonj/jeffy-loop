# Jeffy eval: DaveGamble/cJSON

**Target**: [DaveGamble/cJSON](https://github.com/DaveGamble/cJSON) (12,916 stars, verified via `gh api repos/DaveGamble/cJSON --jq '.stargazers_count'` on 2026-08-12) at tag `v1.7.19`, commit `c859b25da02955fef659d658b8f324b5cde87be3`, MIT. C, in a local clone; the loop's work was never pushed anywhere. cJSON is the ubiquitous C JSON parser, vendored into a very large amount of embedded and desktop software.

**This is a full `/jeffy` loop run that reached machine-checked convergence, in one run of 10 iterations.** **Eight findings closed - 4 High, 3 Medium, 1 Low** - with **three Lows carried on the ledger** at the declaration. The shipped-code change is **5 files, +168/-11** across `cJSON.c`, `cJSON.h`, `cJSON_Utils.c`, `CMakeLists.txt` and `library_config/uninstall.cmake`, alongside **+208 lines of tests carrying 38 new assertions**. Converged at `6aa7e5acc5b5655a918c26924d0e4a36c59d0a41` on 2026-08-12: all **24 surface-inventory rows swept**, and the adversarial evaluator's PASS on record **after one rejection**.

It is the eleventh language in the study, and the first target picked under a selection rule that had just been rewritten.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative above; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).

The ledger rule that countersignature was given under is engine v1.9.0's **severity floor** rather than an empty ledger - zero open High and zero open Medium, with Lows filed, carried and published. This run carried three, listed below. It is the first convergence in the study that the earlier empty-ledger rule would have refused, and the eras are not pooled: the other 21 converged targets met the stricter rule.

## The pick was a falsifiable prediction, and it is the point of this receipt

The preceding targets had been chosen for oracle purity - a conformance corpus the loop cannot rewrite into agreement. That rule points exclusively at protocol and spec implementations, and across this study those took five or more runs and mostly never converged at all, while every single-purpose library with a bounded public API converged inside two runs. The rule was selecting for the one shape that could not finish.

cJSON was picked to test the replacement rule. It is jsoncpp's C sibling, and [jsoncpp](../jsoncpp/REPORT.md) converged in 1 run of 10 iterations. So the prediction was written down before the first iteration, in the form that can fail:

> Pre-registered budget: `/jeffy 10` per run, **maximum 2 runs**. Every single-purpose library in the record converged within two. If cJSON has not converged by the end of the second run, it is published as a non-convergence rather than extended - the point of picking by shape is that the prediction is falsifiable.

It converged in one run of ten iterations, to the iteration.

## What was found

| ID | Severity | Class | Finding |
|:---|:---|:---|:---|
| F1 | **High** | correctness | `sort_list` rebuilds an object's child list without restoring the circular tail pointer, so **every later append is silently dropped** |
| F2 | **High** | security | `cJSON_DetachItemViaPointer` accepts an item belonging to a different parent, cross-linking the two documents and corrupting the original's tail |
| F7 | **High** | security | a heap use-after-free in `replace_item_in_object`, filed and closed by the same root-cause change as F4 |
| F8 | **High** | build | the project does not configure on CMake 4.x - both `cmake_minimum_required` floors sit below CMake 4's hard minimum of 3.5 |
| F3 | Medium | correctness | `parse_number` accepts RFC 8259 violations because it delegates the grammar to `strtod`, which is more permissive than JSON |
| F4 | Medium | correctness | `replace_item_in_object` adopts the caller's lookup string as the member key, silently renaming a member matched case-insensitively |
| F9 | Medium | testing | a leaking test the run itself introduced (see below - this one was filed by the evaluator) |
| F5 | Low | documentation | `cJSON_InsertItemInArray` silently appends when `which` is past the end and returns true, a contract stated nowhere |

**F1 is the finding to read first.** Sorting an object rebuilt its child list forward but never repointed `child->prev` at the new tail, and cJSON stores the tail there. `add_item_to_array` reads that pointer and does nothing when it is NULL, so every subsequent `cJSON_AddItemToObject` on a sorted object was silently dropped, reported as success, and leaked. Sort an object, add to it, and the addition never appears in the document or its output.

The fix lands in `sort_object` in `cJSON_Utils.c` - `sort_list` itself cannot do it, because the recursion has no way to tell a sub-list head from the whole list's head:

```c
    for (tail = object->child; (tail != NULL) && (tail->next != NULL); tail = tail->next)
    {
    }
    if (object->child != NULL)
    {
        object->child->prev = tail;
    }
```

The same invariant is corrupted by `cJSONUtils_GeneratePatches` and the merge-patch generator, which sort their inputs in place even though the caller never asked for a sort. Both are covered by the regression tests.

**F8 fixed the build floors** from `VERSION 3.0` and `VERSION 2.8.5` to `VERSION 3.10`.

## Three Lows were carried, and that is what let this run finish

Under every earlier engine version, a convergence required an **empty** ledger. This run declared with three open items:

- **F6** (Low, testing) - the fuzz harnesses reach only cJSON parse and print, never `cJSON_Utils`
- **F10** (Low, documentation) - every function that adopts an item requires that item to be unowned, and the contract is not written down
- **F11** (Low, testing) - the Verify command runs neither a sanitizer nor a valgrind leg, so it cannot see a leak

Engine v1.9.0 changed the convergence condition from an empty ledger to a **severity floor**: zero High and zero Medium, with Lows filed, carried and published rather than blocking. This is the first run in the study to actually exercise it. Under the previous rule this run could not have declared at all, and the work above would have sat unfinished behind three documentation and test-coverage notes.

**F11 is the loop filing a limitation of its own gate**, in its own words, rather than leaving the gap unnamed. That matters, because the gate's blindness is exactly what the evaluator caught it with.

## The rejection

The gate ran at iteration 9 and returned **REJECT**, on one finding, and it is the most instructive part of this run.

Iteration 5 added a regression test for F4:

```c
TEST_ASSERT_FALSE(cJSON_ReplaceItemInObjectCaseSensitive(object, "aA", cJSON_CreateNumber(9)));
```

The replacement is correctly refused, so it is never adopted, and **nothing frees it**. A definite 64-byte leak, in a test the run wrote to prove a fix. The sibling test the same iteration added forty lines earlier gets it right and carries the comment `/* a refused replacement is not adopted, so the caller still owns it */` before `cJSON_Delete(replacement)`. Line 865 is the same situation with the free omitted.

**The run's own Verify command could not see it, for two compounding reasons.** Its `PLAN.md` Environment fingerprint declares `ENABLE_SANITIZERS` and `ENABLE_VALGRIND` both OFF. And on this toolchain, turning sanitizers on would not have been enough either: cJSON's own CMake flag probe records `-fsanitize=address` as unsupported and **silently drops it**, so an `ENABLE_SANITIZERS=ON` build grades UndefinedBehaviorSanitizer and not AddressSanitizer at all.

The evaluator did not take the green suite at its word. It built with sanitizers, got the LeakSanitizer trace naming `cJSON_CreateNumber` at `tests/misc_tests.c:865`, then ran the **identical** suite at the run's own start commit and got exit 0 at 22/22 - establishing that this run introduced it rather than inheriting it. Then it established that it mattered upstream: `.github/workflows/CI.yml` runs a valgrind leg and a sanitizers leg on every push, and `tests/CMakeLists.txt:70` wraps every registered ctest test in `valgrind --trace-children=yes --leak-check=full --error-exitcode=1`. A definite leak fails that leg.

So the run's suite was green, the project's own CI would have gone red, and the gate is what stood in between. Iteration 10 closed it as F9 and re-invoked, and invocation 2 returned **PASS**.

This is the case the adversarial evaluator exists for. Not a difference of opinion about severity - a defect the project's local gate was structurally incapable of seeing, found by a fresh context that refused to accept the gate's own scope.

## Two facts were known before the run and deliberately withheld

The target brief written during setup recorded two properties of this repository. Neither was told to the loop, because a finding handed to a run is not a finding.

1. **cJSON does not configure on CMake 4.x.** The loop found it in iteration 8 and scored it **High** (F8).
2. **`ENABLE_SANITIZERS=ON` silently drops `-fsanitize=address` at cJSON's own flag probe**, verified during setup from `CMakeFiles/cjson.dir/flags.make` and `ldd` rather than from `CMakeCache.txt`, which records only what was requested. The **evaluator** rediscovered this independently, as the explanation for why the run's gate could not see the leak.

Both were found from the inside, by the run and by its gate, with the answer sitting unread in a file outside the repository the whole time.

## The Verify command, and what it does and does not grade

```
rm -rf build && cmake -S . -B build -DENABLE_CJSON_UTILS=ON -DENABLE_CJSON_TEST=ON > /dev/null \
  && cmake --build build -j8 > /dev/null \
  && ctest --test-dir build --output-on-failure
```

Exit 0 in **18 seconds**, **22 of 22 tests**, re-run independently against the converged tree for this receipt. The loop declared a full clean rebuild rather than an incremental one, so a stale object file cannot carry a passing result forward.

Declared limits, in the run's own inventory and repeated here because a receipt that omits them is worth less:

- **No valgrind leg locally.** valgrind requires root to install on this host and was not available. The upstream valgrind CI leg is not reproduced here.
- **No AddressSanitizer**, for the flag-probe reason above. This is F11, carried.
- **Non-ASCII enum-style identifiers are not exercised**, an unrelated host limit recorded during setup.
- The known-answer battery the loop built for itself lives at `.jeffy/probes/api-known-answer/`, compiled `-std=c89 -pedantic -Wall` against the working tree.

## Surface

All **24 surface-inventory rows swept**, none unswept, none unreachable. Iteration 7 was a full fresh-evidence audit that closed the last three - build-packaging, fuzz-harness and docs.

## Disclosure

F1 is the strongest upstream candidate and needs no judgement call from a maintainer: sort an object, append to it, observe the append vanish. Its acceptance test asserts only that an item added after a sort is present in the document.

Findings have not yet been disclosed upstream as of this writing.
