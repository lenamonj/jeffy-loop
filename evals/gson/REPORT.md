# Jeffy eval: google/gson

**Target**: [google/gson](https://github.com/google/gson) (24,229 stars) at master tip `0482d5ca` on the day of the run, OpenJDK 21 with upstream Apache Maven 3.9.12 - run in a local clone; nothing was pushed upstream. The seventh language in this set.

**The frame.** gson was chosen the same way RuboCop was: for maintainer engagement, on the evidence that its Google maintainer had merged four outside correctness fixes in the week before the run. That evidence cut both ways. The five commits immediately preceding the baseline are those very fixes - a `JsonPrimitive.hashCode` contract violation, a URI adapter identity bug, non-ASCII digit acceptance, `InetAddress` deserialization hardening - which means the field had been swept by outside contributors days earlier. What this run certifies is that what remained held.

**The headline**: converged in **two iterations**, the fastest run in this set (the previous shortest was seven). One full audit, one evaluator gate. **Zero High, zero Medium; exactly one finding, a Low, filed and declined with its cost stated** under the engine's pricing rule: G1, the benchmarks module's dependency on Caliper 1.0-beta-3, unmaintained since 2015 - declined as `cost: exceeds one iteration`, since migrating benchmarks to JMH and verifying comparable output is multi-iteration work on a module with no runtime users. There is no fixes.patch: no source, test, or build file changed. The certified tree `1a5ecc1c` differs from upstream `0482d5ca` by 188 lines of loop bookkeeping plus a single `.gitignore` line ignoring the loop's own transient state file.

## What "clean" was earned against

gson is compact - 313 tracked files, one Maven reactor - so unlike RuboCop's six audits, one audit swept the whole inventory. The claim rests on:

- **17 inventory rows: 16 swept, one disclosed as unreachable.** The full suite green at baseline - 128 surefire test classes across gson, extras, proto, and metrics, 0 failures - plus `mvn verify -am` on the JPMS module-descriptor tests and the ProGuard/R8 shrinker assertions (133 test classes counting those). The GraalVM native-image harness cannot run on this host and was marked with the engine's `[~]` unreachable state - disclosed in the record rather than silently skipped, the first live use of that mechanism.
- **The adversarial JSON path read at source level**: the 255-element nesting limit, `NumberLimits` bounds, strictness modes, and the just-merged `InetAddress` hardening - scored against malformed and hostile input classes, with error paths verified to raise `JsonSyntaxException`/`MalformedJsonException` carrying JSONPath context.
- **Build-time enforcement noted as part of the posture**: Error Prone 2.50.0 runs in the build, and the runtime gson artifact carries zero dependencies.
- Dimensions that could not be honestly scored were skipped with reasons, not scored clean: performance (no baseline on this host), observability and UX (pure library).

The evaluator then earned its PASS on invocation 1 - and it added accuracy even to a null result: it independently confirmed the tree byte-identical to upstream, re-ran every suite itself, judged the G1 declination honest, and **caught two bookkeeping errors in the audit's own record** - a cited test-battery class that does not exist (java.time coverage lives in `DefaultTypeAdaptersTest`, not a `JavaTimeTypeAdaptersTest`) and a wrong surefire class count (134 claimed, 128 true). Both were corrected in the closing entry under the journal's no-rewrite rule, and the run's Lesson is the general form: cite battery classes from `git ls-files` output, not from memory.

## What the run did

1. **Salvage + audit** (iter 1/10) - bootstrap files committed by the salvage rule, then the full audit: envelope, 17-row inventory, verify command through the Windows-to-WSL bridge, every dimension scored on swept rows only. Ledger emptied same iteration: the one finding filed was priced and declined. Closeout declared.
2. **Evaluator gate + declaration** (iter 2/10) - gate and declaration in one iteration. `Evaluator: PASS` in the closing entry, `Converged: 1a5ecc1c` appended, and the Stop hook's machine checks - empty ledger, resolvable Converged hash, no unswept row, verdict present, verify command exit 0 on the hook's own re-run - accepted on the first attempt.

Full record: [journal.md](journal.md).

## The limits, stated plainly

- A two-iteration run is a breadth certification of a compact, densely tested library, not an adversarial campaign per type adapter. The audit's depth was one pass over each surface plus source-level reads of the hardened paths.
- The GraalVM native-image tests never ran on this host (`[~]`).
- The field was freshly swept: four outside correctness fixes merged the week before the baseline are part of why there was nothing left at this method's severity bar. A run against the same tree a month earlier would likely have found what those contributors found.
- G1 remains real and open upstream by our decision, not theirs: the benchmarks module's Caliper dependency is unmaintained. It is a Low in a dev-only module, priced as exceeding one iteration, and revisitable.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative above; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).

**Status**: nothing lives in this eval's artifacts but the record itself - the certified tree is upstream `0482d5ca` plus loop bookkeeping. Findings were not disclosed upstream: the sole finding is a declined Low in a benchmarks-only module.
