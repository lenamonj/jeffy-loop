# Jeffy eval: apple/swift-algorithms

**Target**: [apple/swift-algorithms](https://github.com/apple/swift-algorithms) (6,323 stars, verified via `gh api repos/apple/swift-algorithms --jq '.stargazers_count'` on 2026-08-12) at tag `1.2.1`, commit `87e50f483c54e6efd60e885f7f5aa946cee68023`, Apache-2.0 with Runtime Library Exception. Swift, in a local clone; the loop's work was never pushed anywhere. swift-algorithms is Apple's open-source package of sequence and collection algorithms.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative above; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).

**This is a full `/jeffy` loop run that reached machine-checked convergence, in three runs of 24 iterations.** **Fifteen findings closed - 1 High, 9 Medium, 5 Low** - with **three Lows carried** at the declaration. The shipped change is **12 files, +101/-50** under `Sources/Algorithms/`, plus **+86 lines of tests** and 4 guide files. Converged at `2f0c05fb6d37b1f37c8937ad17250fe5060ef91c` on 2026-08-12: all **32 surface-inventory rows swept**, and the adversarial evaluator's PASS at invocation 1 of run 3, after **two terminal rejections in run 2**.

Swift is the twelfth language in the study.

## The one High, and why the rest are what they are

**ALG-1**: `CombinationsSequence.count` returned wrong values and trapped on ordinary input. That is the whole of the runtime-correctness haul, and it is worth saying plainly: this is mature, heavily reviewed Apple code, and the loop found one genuine defect in it.

The other fourteen cluster into a class that says something specific about the project:

| ID | Severity | Finding |
|:---|:---|:---|
| ALG-2 | Medium | **nothing compiled or ran the code examples in the doc comments** |
| ALG-4 | Medium | ten doc-comment examples did not compile |
| ALG-5 | Medium | doc examples stating output the code does not produce |
| ALG-6 | Medium | six doc comments described behaviour the code beside them does not have |
| ALG-3 | Medium | all eight `min(count:)`/`max(count:)` comments promise an ordering guarantee for equal elements |
| ALG-7 | Medium | the guides named an API that does not exist |
| ALG-9 | Medium | the six deprecated `scan` entry points had no test at all |

ALG-2 is the root and the rest are its consequences. `swift test` grades the implementation; nothing graded the prose. Apple's CI runs the test suite, a formatting check and an API-breakage check, none of which compiles a doc comment, so this surface was **ungraded upstream rather than merely unfixed**. Once the loop built something that compiled the examples, ten of them turned out not to compile and several others documented behaviour the code does not have.

The remaining findings (ALG-11 through ALG-15) are all defects in the loop's **own** probes, filed by the evaluator or by a later audit. They are counted here rather than quietly dropped.

## The run needed three attempts, and the middle one is the instructive part

| Run | Iterations | Outcome |
|:---|---:|:---|
| 1 | 10 | ledger fully cleared, **did not converge**: 4 of 32 surface rows still unswept |
| 2 | 11 | **blocked** - both evaluator invocations returned REJECT |
| 3 | 3 | swept, closed the last finding, **PASS at invocation 1** |

**Run 1** closed all eight of its findings and ended with an empty ledger and a green suite, which looks converged and is not. Four inventory rows remained: the deprecated `scan` shims, `FlattenCollection`, `EitherSequence`, and the DocC catalog - each reached only indirectly by existing checks. It declined to invoke the gate at all, on the reasoning that the gate belongs to the declaration path, the path was shut, and *"spending an invocation to be told so would put a REJECT on the record for a condition already visible in PLAN.md."*

**Run 2** swept all four rows in its opening audit, then spent both invocations on rejections. The second is the one to read:

> ALG-12's closure is not real: `.jeffy/probes/complexity-claims/probe.swift` claims to drive all 22 documented construction complexity claims and drives 21, and the entry that covers the twenty-second measures a **different function** whose own doc comment states the opposite complexity.

The loop had built a probe to verify its own fix, the probe reported PASS, and the gate found the probe was measuring the wrong function. Invocation 1 had already done something similar, writing its own probe to drive the 13 documented sites the shipped battery did not reach.

### The extension the run refused to use

Run 2 ended with a piece of rule-reading worth quoting, because it is the loop declining a loophole in its own favour. The Stop hook grants a one-time closing extension, which took the budget from 10 to 12. The evaluator cap is 2 invocations, or 3 when the first landed **before** the budget's midpoint. Invocation 1 landed at iteration 5: the midpoint of 10, so not before it. Against the *extended* budget of 12 the midpoint is 6, and iteration 5 would qualify for a third invocation.

> "That reading is refused: it lets a run manufacture an extra invocation by exhausting its budget, which is precisely the wearing-down the cap is called absolute to prevent, and the timing was judged and recorded when the first invocation happened rather than retroactively."

It ended blocked instead.

## Three Lows carried

Under engine v1.9.0 a declaration requires zero High and zero Medium; Lows are filed, carried and published. This run carried three, and all three are defects in its own tooling rather than in Apple's code:

- **ALG-16** - `doc-example-output` can lose a site silently
- **ALG-17** - `joined_values.py` compares in a way that admits a false pass
- **ALG-18** - 14 doc claims written as `// x == y` value assertions are checked by no battery

The gate ran all 14 of ALG-18's claims itself during the passing review and reports that every one holds, so it filed no finding there today and recorded the gap for a future run instead.

## The oracle the loop had to build

`swift test` at the base commit graded the implementation and nothing else. By convergence the run had built **nine probes**:

`algorithms-known-answers` (8,779 checks), `combinations-count`, `complexity-claims`, `doc-examples`, `doc-example-output`, `docc-links` (174), `guide-selectors`, `markdown-links` (377), `minmax-stability`.

That is most of this receipt's substance: on a target whose test suite is genuinely good, the loop's contribution was to grade the surface the suite never touched.

## Verify command

```
swift test
```

Exit 0 in **6 seconds**, **218 tests**, 0 failures, re-run independently against the converged tree for this receipt (the suite grew from 212 at the base commit). Verified before the run began at 10 consecutive passes.

**Constraint declared before iteration 1**: Apple's `Soundness / API breakage check` fails any public-API change, so every fix had to be behaviour-preserving, and `.swift-format` is diffed byte-for-byte against another Apple repository's copy and is untouchable.

## A process disclosure

**No run budget was pre-registered for this target.** Budgets were pre-registered for the two targets before it and the practice was not carried into this cohort's brief, which recorded verify commands and declared limits but no stopping rule. So this run had no rule fixed in advance saying when to stop, and it took three runs where the selection rule that picked it predicted one or two. That is recorded here rather than corrected after the fact, and the remaining targets in the cohort carry pre-registered budgets.

## Disclosure

Findings have not been disclosed upstream as of this writing. ALG-1 is the candidate: `CombinationsSequence.count` returning wrong values and trapping is a self-contained defect with a test that needs no judgement call.
