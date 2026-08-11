# Every target ever started

The receipts table in the README lists what converged. This file lists
everything that was ever *started*, including what did not finish and what was
abandoned, because a method that only publishes the runs that worked is not
being measured.

Derived from the run journals rather than from prose. The iteration column
reproduces each receipt's own published figure, so this table and the README
agree; where a receipt counts salvage and rotation entries and another counts
per-run maxima, the difference is a counting convention and never a different
run. Runs count distinct run identifiers, except in the four earliest journals
whose heading grammar predates run tokens, where runs are counted by budget-arc
restarts and corroborated against each receipt's own text. One journal (`ta`)
is lossy by its own admission: 18 entries from its first three runs were
destroyed by a rotation defect that run exposed, and the receipt records the
loss rather than hiding it.

## Brownfield

| Target | Runs | Iterations | Outcome | Standard met | Runs that ended blocked |
|---|---:|---:|---|---|---:|
| bat | 1 | 10 | converged | evaluator countersigned | 0 |
| BurntSushi/toml | 5 | 52 | **not converged** | n/a | 3 |
| chalk | 2 | 8 | converged | pre-evaluator | 0 |
| dayjs | 8 | 74 | converged | evaluator countersigned | 1 |
| eemeli/yaml | 5 | 50 | **not converged** | n/a | 0 |
| fasthttp | 7 | 58 | converged | evaluator countersigned | 0 |
| go-yaml | 3 | 29 | converged | evaluator countersigned | 0 |
| goldmark | 5 | 47 | **not converged** | n/a | 0 |
| gson | 1 | 2 | converged | evaluator countersigned | 0 |
| image-rs (attempt 1) | 2 | 10 | **not converged** | n/a | 2 |
| image-rs (attempt 2) | 3 | 30 | **not converged** | n/a | 0 |
| jsoncpp | 1 | 10 | converged | evaluator countersigned | 0 |
| mruby (attempt 1) | 5 | 50 | **not converged** | n/a | 0 |
| mruby (attempt 2) | 5 | 63 | **not converged** | n/a | 1 |
| mustache.js | 2 | 11 | converged | pre-evaluator | 0 |
| PHP-Parser | 3 | 29 | converged | evaluator countersigned | 0 |
| PyPortfolioOpt | 6 | 58 | converged | evaluator countersigned | 1 |
| python-dotenv | 8 | 73 | converged | evaluator countersigned | 1 |
| quantstats | 4 | 40 | converged | evaluator countersigned | 0 |
| records | 1 | 7 | converged | pre-evaluator | 0 |
| rrule | 4 | 33 | converged | evaluator countersigned | 0 |
| RuboCop | 1 | 7 | converged | evaluator countersigned | 0 |
| rust-url | 3 | 30 | converged | evaluator countersigned | 0 |
| sqlparse | 5 | 47 | converged | evaluator countersigned | 2 |
| Spectre.Console | 1 | 8 | converged | evaluator countersigned | 0 |
| speedtest-cli | 1 | 5 | converged | pre-evaluator | 0 |
| ta | 6 | 64 | converged | evaluator **unavailable**, recorded | 0 |
| yfinance | 1 | 9 | converged | evaluator countersigned | 0 |
| PapaParse | audit only | - | audit, not a loop run | n/a | - |
| **libuv** | at least 1 | at least 1 | **abandoned, no receipt** | n/a | - |

## Greenfield

| Target | Runs | Iterations | Outcome | Runs that ended blocked |
|---|---:|---:|---|---:|
| TOML decoder | 1 | 11 | converged | 0 |
| gitignore matcher | 5 | 42 | converged | 3 |
| TOML-M (mutated spec) | 1 | 14 | converged, with a disclosed process violation | 0 |

## The convergence standard is not uniform, and here is the split

The engine tightened over time. Of the 21 brownfield convergences:

- **16** were countersigned by the adversarial evaluator, the current standard.
- **1** (`ta`) records the evaluator as `unavailable` - that session carried a
  standing instruction against sub-agents, and the receipt says so rather than
  working around it.
- **4** (`chalk`, `mustache.js`, `records`, `speedtest-cli`) predate the gate
  entirely and converged under the earlier standard: a clean closing audit and
  an empty backlog.

Every receipt names the standard its own run met. Pooling all 21 as one number
would overstate the earliest four.

## What was started and never published

- **libuv.** A real loop run on a WSL clone, 2026-07-31. At least one full
  iteration completed. It produced two engine lessons that are on the release
  backlog to this day: a pre-flight refusal for `core.autocrlf` on a non-Windows
  tree (the loop caught that its own revert path would have rewritten every
  source file), and a refusal for verify commands ending in a truncating pipe
  (its first suite run reported exit 0 while 13 tests were failing). The run was
  not carried to convergence and has no receipt directory. It is the one
  genuinely abandoned public target.
- **A private project ("tradestudio").** At least three runs, 2026-07-30. It
  produced the lesson that probe batteries must be re-run at close: running
  every battery at that run's wrap-up caught a six-iteration-old regression
  every verify gate had reported green. Not published because the code is
  private.
- **This repository itself.** The loop is run against its own tree
  periodically; the closing sequence of one such run is quoted in the README.
  Its state files are the loop's working memory rather than a receipt, and stay
  out of the published tree.

## Honest reading of these numbers

Convergence here is per-run, and a blocked run is relaunched from written
state with a fresh evaluator budget. Under that protocol, persistence raises
the chance of eventually converging - dotenv took eight runs, dayjs eight,
gitignore five with three terminal rejections along the way. The run counts
above are published precisely so that "21 converged" is read with the cost
attached rather than as a success rate.

Targets from here on carry a **pre-registered run budget** committed before
their first iteration, so the stopping rule is fixed in advance rather than
chosen after seeing the outcome. TOML-M was the first, at five runs; it used
one. `go-yaml` was the second, also at five runs; it used three and the
remaining two were not spent, because a budget is a ceiling rather than a
quota. `rrule` was the third, at five runs; it used four.

`sqlparse` was the fourth, at five runs, and it is the first target where the
budget nearly bound. Four runs failed, two of them ending blocked, and the
expectation written down after run 4 was that it would be published here as a
non-convergence. It converged on the fifth and last budgeted run, at iteration
8 of 10. Seven evaluator rejections preceded that PASS. The rule was capable of
producing the unwelcome answer up to the final run, which is the only condition
under which a stopping rule is worth publishing at all.

`rust-url` was the fifth, also at five runs; it used three. Its budget never
came close to binding, which is the opposite outcome to `sqlparse` and is
recorded here for the same reason: a pre-registered budget is only evidence if
both results get published.

`PHP-Parser` was the sixth, at four runs; it used three.

`goldmark` was the seventh, at four runs, and it is **the first pre-registered
budget that bound and returned the unwelcome answer.** Four runs, 40
iterations, no convergence. Under the rule fixed before iteration 1 that is
where it stops. Until now every pre-registered budget had ended in a receipt -
`sqlparse` came closest and converged on its last budgeted run - so this row is
the first evidence that the stopping rule can actually cost something rather
than merely being capable of it in principle.

The disclosure that belongs beside it, in the same plain terms as TOML-M's:
**a fifth run was launched 24 minutes after run 4 wrapped, and ran seven
iterations before it was caught and stopped.** It was momentum, not a decision
to extend - nothing in the launch, the loop state, or the journal says a budget
has been spent, and no one checked. Had it converged, the convergence would
have been bought by extending the budget after watching four runs fail, which
is the outcome pre-registration exists to prevent, and no quality of fix would
have rescued it.

That fifth run and its seven iterations are **counted in the table above rather
than removed.** A file whose purpose is that no run gets deleted from the
record does not get to delete the run that should not have happened. The line
held instead is between counts and claims: the counts include run 5, and no
claim here rests on it. The engine change that would have caught it - the
launch printing how many runs this target has already had, before adding
another - is on the release backlog.

## BurntSushi/toml, where the gate was the only thing standing in the way

`BurntSushi/toml` is a Go TOML library, and it is **not** the greenfield TOML
decoder or TOML-M in the table below - three different targets, never pooled.

It ended at its declared ceiling without converging, and the shape of that
failure is the reason it is worth reading. At the end it had **22 of 22 surface
rows swept**, a green `go test -race` suite, fourteen green probe batteries, a
clean `go vet` and `gofmt`, a clean `GOARCH=386` build, and an empty ledger.
Every mechanical closing condition the engine checks was satisfied. **Seven
adversarial evaluator invocations returned zero passes.**

**What blocked it was prose, not code.** The terminal rejection named two
Mediums, both in documentation, and **both were false sentences the final run
wrote itself** - one at iteration 2 and one at iteration 8, the second in the
task whose entire purpose was to make an inaccurate comment true. Each
generalised a claim from the single input shape its own test drives: a godoc
sentence about which limit an over-nested inline table is reported against,
true only for the one form the boundary test exercises; and a sentence about
whitespace indentation that is false for five values carrying a newline. The
evaluator reproduced counter-examples for both before filing them.

That class - a prose claim wider than the evidence behind it - was already
written down as a Lesson in this project's own `PLAN.md`, and it happened twice
anyway, in the two iterations that decided the run.

**A pass here would have shipped two false godoc sentences into a library other
people read.** No test suite can catch that: a wrong sentence in a doc comment
compiles and goes green. Only a reader that re-derives the claim against the
code finds it, which is what the adversarial gate is for and why a rejection at
this point is a better outcome than the receipt would have been.

One caveat stated plainly rather than buried: this target ran **three runs with
no written budget at all** before a five-run ceiling was declared ahead of run 4,
with three runs of outcome already visible. That is weaker than a
pre-registration and is not described as one. The ceiling still bound - the run
that reached it stopped rather than continuing into a sixth.

## image-rs, twice, and the second one was stopped by a rule that worked

`image-rs` was attempted twice, and **both attempts are listed separately
rather than pooled.** Their baselines differ in the one way that decides what a
result means, and pooling would hide the more instructive half.

**Attempt 1 failed because of the operator, and that is stated rather than
softened.** Its baseline pinned the `pic-scale-safe` dependency *backwards*, to
a version below what the crate's own manifest resolves, in order to manufacture
a green start. Upstream declares a caret range and does not track `Cargo.lock`,
so **no user and no upstream CI run has ever seen the version that run
measured.** Worse, the pin concealed a live defect: upstream `main` was red on
that very test, on the tip of the branch, the day before. Inside its
manufactured world the loop did find a genuine High in the resize border
handling, correctly refused to unpin on its own authority, filed the blocker,
and handed the decision back - it behaved well in a world that should not have
existed. Two runs, 10 iterations, both ending blocked.

**Attempt 2 started deliberately red** - no pin, a fresh resolve, the same
version upstream CI resolves, with the suite failing at the baseline exactly as
it fails for anybody who builds the project. It ran three of a pre-registered
five.

At the run-2/run-3 boundary an **abort criterion** was added: 19 of 42 surface
rows swept by the end of run 3, or stop. That criterion is honestly weaker than
a pre-registration - two runs of outcome were already visible when it was
written, and it says so - but it was fixed before run 3 began and it decided the
outcome rather than being chosen afterwards. Run 3 finished at **15 rows**. The
criterion fired and attempt 2 stopped at 30 iterations rather than 50.

**It fired on a hypothesis that was correct.** The criterion existed to test
whether the sweep rate was front-loaded by instrument-building and would
accelerate once the batteries existed. It did: 0.50 rows per iteration in run 1,
0.30 in run 2, then **0.70 in run 3**, the fastest of the three and more than
double its predecessor. It was still not close to the 1.6 per iteration needed
to finish. A hypothesis can be right and the answer still no, and the value of
writing the number down beforehand is that the run gets to prove itself without
the number moving to accommodate it.

So attempt 2 is **a finding about budget sizing rather than about image-rs**: a
47-row surface probed at roughly one known-answer battery per row does not fit
fifty iterations. Its own surface inventory grew from 42 rows to 47 mid-run,
because an audit correctly split an oversized row into six function families
rather than let one checkbox stand for a module - which is the behaviour that
makes the coverage number mean something, and which no faster-looking run
elsewhere in this table should be assumed to have done.

## mruby, twice, and the evaluator that was never due

mruby is a bytecode VM for Ruby, written in C. Both budgets were
pre-registered in the cohort brief before their first iterations: attempt 1 at
five runs of ten, and attempt 2, declared after attempt 1 ended, at four runs
of fifteen. Attempt 1's rows are published here for the first time - its
pre-registration promised publication and the rows were never added, the same
debt image-rs attempt 1 settled, and this paragraph settles it. Attempt 1 spent
all 50 iterations and did not converge.

Attempt 2's iteration count needs its arithmetic shown. The four budgeted runs
spent 61 iterations: three ran their full fifteen, and one ran sixteen by using
the engine's one-time +2 closing extension before ending blocked. The other two
iterations are a disclosed operator error: a run was launched with a
10-iteration ceiling against the declared 15, caught at iteration 2, and
cancelled. Those two iterations are counted in the table rather than removed -
a file whose purpose is that no run gets deleted from the record does not get
to delete the run that should not have happened - and no claim here rests on
them.

The disclosure that belongs beside the rows: mruby's oracle was rated the
weakest in its cohort at selection, and the rating was written down before the
first run. The in-repo suite - quoted at
selection as 1,925 unit tests and 105 binary tests - is fully editable by the
loop, so the shipped harness alone cannot overrule it. What was declared as the real measurement was whether the loop would reach
for the external oracle, CRuby 3.3.8 installed beside it, without being told
to. It did, from the first run onward: the journals record per-family probe
batteries that drive both implementations and diff the answers - a
fourteen-read enumeration over named captures, corpus differentials over
sprintf and bignum arithmetic, a 39-line matrix over dig - and the divergences
those probes pinned are what most of the closed findings are. The suite was
also extended with regression pins as fixes landed, which an editable oracle
permits; the differential batteries are the part the loop could not have
rewritten into agreement.

What the two attempts bought is a finding about the convergence gate itself.
Across ten runs and 113 primary iterations, the adversarial evaluator never
ran once - not skipped, never due. The gate fires when the task ledger empties
with a clean full audit already on the record, and on a surface this size that
conjunction never occurred: the final run's ledger emptied at iteration 12
before any audit had been recorded, the audit at iteration 13 filed four new
findings and refilled it, and the run ended two iterations later. This is not
a discipline story - the project's backlog carries 48 settled defect classes,
each with an enumerating check, and the final run alone closed twelve tasks
including one High driven to class-completeness across three iterations. It
is a reachability story: eight of the 28 mapped surface rows were still
unswept when the budget ran out, several cost a full iteration just to build
the instrument, and two need a build variant the project's own recorded
lessons forbid in this tree. A target can be worked by the rules, every run,
and still never legally meet its evaluator inside the budget the rules fixed.

Under the rule fixed before iteration 1, that is where it stops. What a future
attempt would inherit is written in the final run's handoff: a clean tree, a
green gate, three Low findings with acceptance checks already executed, one
blocked Medium, and four decisions that belong to the user rather than the
loop. No third attempt is declared here.

## eemeli/yaml, where the gate was never due either

`eemeli/yaml` is a YAML 1.2 parser and stringifier written in TypeScript and
published as the `yaml` npm package. It is **not** `go-yaml`, which is a
different target in the table above and converged; the two are never pooled.

Its budget was pre-registered at five runs of ten before the first iteration,
and it was spent exactly. Five runs, fifty primary iterations, every journal
heading carrying a `/10` denominator and no iteration numbered past ten: no
`+2` closing extension, no cancelled fragment, no run started after the last
wrap-up. This row therefore carries no arithmetic disclosure, unlike
`goldmark`'s momentum run and `mruby` attempt 2's ceiling that did not match
its declaration - and the reason is not virtue but a practice those two
produced, the launch being checked against the pre-registration rather than
assumed. The last two launches were checked that way. Both pinned conformance
corpora carry the SHAs recorded at adoption, verified at close.

It did not converge. The Definition of done requires the Surface inventory to
list no unswept row, and ten of 26 remained. The sweep went 0, 7, 10, 13, 16 -
the first run swept nothing, spending its whole budget on defects, and each of
the last three swept exactly three rows. At three rows a run, 26 rows need
roughly nine runs. **The budget was never feasible for the definition of done
it was measured against, and that was computable at the first audit rather than
at the fifth run.** The tier that produced five-by-ten was applied correctly;
the arithmetic underneath it was not performed. That is the same lesson
`image-rs` produced from the opposite direction, and the engine change that
would run it automatically is on the release backlog.

**The finding worth the row is that the adversarial evaluator never ran - not
once in fifty iterations.** Not skipped: never due. The gate fires when the
ledger empties with a clean full audit already on record, and on a 26-row
surface swept three at a time that conjunction never occurred.

That is the second independent time this has happened, after `mruby`'s ten runs
and 113 iterations, and it is the more informative of the two. `mruby` is a
bytecode VM in C and could be read as a story about size. This is an
ordinary-sized library, 76 TypeScript files under `src/`, of the kind this
corpus is mostly made of. **The reachability bound sits lower than the first
datapoint suggested, and sizing the budget by tier does not fix it.** What a
per-run convergence protocol can certify on a surface above some size is a real
open question in the engine's design rather than a property of these two
targets.

Two moments in the final run are worth publishing on their own, because both
are refusals and refusals are the part of a method that is hard to fake.

**The conformance corpus vetoed a working fix, and the loop took the veto.**
Aliased duplicate map keys went undetected; the fix was written, was a clean
boundary rather than scattered patches, added no import cycle, and made all
five reproduction cases report `DUPLICATE_KEY`. Then the suite went red on
`yaml-test-suite` case X38W, which lists an alias key denoting the same node as
another key as valid. One line in the project's own skip list would have turned
the gate green - and that list already overrides the corpus on this exact
question once, for duplicate empty keys. The run did not add the line. It
reverted the fix, left the finding open, and filed the semantic question for
the maintainer with both authorities argued and the reverted fix described. Its
reason, in its own words: the skip list is where the maintainer records
deliberate deviations, and adding to it to land your own change is weakening a
test to pass a change. It also checked the corpus's own tags rather than
assuming, and found `2JQS` tagged `duplicate-key` while X38W is tagged
`alias complex-key flow` - the corpus authors appear to have considered alias
keys and deliberately not counted them as duplicates.

**A probe was deleted rather than repaired, and the deletion was earned first.**
One battery printed twenty failures and exited 0, so the previous run's claim
that all batteries pass had counted it green - a batch check reads exit status.
Before removing it, every one of the twenty was accounted for: sixteen were
superseded by rows that now carry authoritative batteries, and the remaining
four were executed directly and shown to be defects in the probe rather than in
the library. What replaced it is a guard over the whole probe tree that fails
when any script's output and exit status disagree, proven with a freshly
written liar rather than the artefact just removed. Repairing it instead would
have meant hand-writing twenty answers for twelve rows nobody had swept, which
is the sweeping work done badly; wrong breadth coverage is worse than none.

One more finding generalises past this target. A High in the fourth run was
invisible to 3,485 passing tests: the published CLI could not load a `--visit`
visitor at all on this platform, because the test file calls the CLI in process
and the test runner rewrites dynamic `import()`, so those tests graded the
runner's module resolver instead of Node's. It was found by running the
published binary as a subprocess. A Medium in the same run had been dead since
a major refactor because nothing executes the script carrying it. Both say the
same thing, and the run said it better than this paragraph can: a green suite
bounds what the project exercises, never what its consumers can reach.

Under the rule fixed before iteration 1, that is where it stops. Ten rows
remain, all in the parse and compose direction, and the final wrap-up names
which to take first and why. Two Highs are blocked on semantic decisions that
belong to the upstream maintainer rather than to the loop. No second attempt is
declared here.
