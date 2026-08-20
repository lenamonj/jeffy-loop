# Jeffy eval: square/moshi

Square's JSON library for Android, Java and Kotlin, and **the thirteenth
language in the corpus**. It is also the corpus's clearest instance of a
target the engine could not finish under one release and finished under the
next: three runs and thirty iterations left it with an empty ledger, five
unswept rows, and **the evaluator gate never once invoked** - the fourth
target to end that way. Two further runs under a changed engine cleared the
map and converged. **5 runs, 49 iterations, converged** at
`b72a4faca81d5f84989ea26f2095dbaf29307431`, against a pre-registered budget
of 4 runs of 10 for the first attempt and 2 of 10 for the continuation.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `master` HEAD `889013ec2edb8d8034902662a1dc8c4f3b3f8111` (moshi's tag naming is irregular, so the green baseline is this exact SHA) |
| Upstream CI on the base | **20 of 20 green** |
| Findings closed | **27** - 5 High, 18 Medium, 4 Low |
| Shipped-code change | 38 files, **+633 / -167** |
| Surface inventory | **32 of 32 rows swept** |
| Ledger at convergence | **5 Lows carried**, four documentation and one dev-tooling |
| Evaluator | **2 invocations: REJECT, then PASS** |
| Runs that ended blocked | 1 |

## What the loop found

Five Highs behind a suite twenty green CI legs called clean, all in the
paths that turn bytes into typed values:

- **`JsonValueReader`'s integral reads returned silently out of range** - a
  value too large for the requested type came back wrong rather than
  refused, on the reader every `readJsonValue` consumer uses.
- **the date-only branch of the RFC 3339 parser read the wrong offset**, so
  a bare date parsed against the wrong instant.
- **every exception a Java record's canonical constructor throws was
  swallowed**, turning a validating constructor into a silent one.
- **a `KType`'s nullability marking decided nothing** for one adapter path,
  so a non-null Kotlin property accepted null.
- one further High in the same family, closed with the class rather than
  the site.

The eighteen Mediums are mostly the same shape one level down - adapters
disagreeing with the contract their KDoc states - and the four carried Lows
are documentation and one duplicated probe label.

## The engine change is part of this receipt, stated with its confound

Runs 1 to 3 (2026-08-17, engine 1.10.0) closed 17 findings and swept 27 of
32 rows, then ended with an empty ledger, five rows unswept, and no gate
invocation: under that ordering an open Medium outranked an unswept row, so
the map never finished and the declaration path never opened. Runs 4 and 5
(2026-08-20) ran under **1.12.0**, whose defining change makes the map
outrank everything but an open High. Run 4 swept the remaining five rows in
its first iterations and reached the gate for the first time on this
target; run 5 converged at its seventh iteration.

The confound is stated rather than hidden: runs 4 and 5 inherited a tree
that was already 84 percent mapped, so they had less to do than a cold
start. What the change is fairly credited with is the ordering that put
those last five rows above the ledger, and the observation that three runs
under the older rule left them unswept while the first run under the new
one did not. One target is one target; the corpus, not this receipt, is
where that claim gets tested.

## Declared limits

- **`./gradlew build` on an unchanged tree reports `:moshi:test UP-TO-DATE`
  and exits 0 with zero tests executed** - the purest instance of the
  cached-verify trap in the corpus. The verify command is therefore
  `./gradlew cleanTest test --console=plain`, which re-executes every test
  task each run.
- **JDK 17 was installed for this target** (alongside the host's 21): the
  `records-tests` module pins a Java 17 toolchain and Gradle does not
  auto-provision here. The pin is the project's own and was not edited.
- The first attempt is published in `ATTEMPTS.md` as what it was at the
  time - three runs, not converged, gate never due - and this receipt
  supersedes the outcome without softening the record, the way
  `python-dotenv`'s did.
- Graded under WSL2 Linux x86_64, run headless by `claude -p` on
  **claude-opus-5 (1M context) at xhigh effort**, engine 1.10.0 for runs
  1-3 and 1.12.0 for runs 4-5.

## Nothing was sent upstream

Every finding rests on probes and tests this loop wrote; no existing test
was deleted, disabled or weakened. The gate's first invocation REJECTed and
its findings were worked before the second was spent, which is the sequence
the invocation cap exists to force.
