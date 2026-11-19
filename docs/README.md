# Jeffy Loop documentation

| Page | What it covers |
|:---|:---|
| [Usage](usage.md) | Flags, rounds and budgets, scoped mode, cancelling, upgrading, uninstalling, and what to know before a first run |
| [Headless runs](headless.md) | Running budgeted rounds unattended from bash or PowerShell |
| [How it works](how-it-works.md) | The run lifecycle, what the engine enforces, the full rule set, a converged stop, and how the loop improves itself |
| [Recursive self-improvement](recursive-self-improvement.md) | What RSI means in Jeffy: the cycle it runs on its own engine, the step a human in the loop keeps, the guardrails, and what it is not |
| [Recursive self-learning](#recursive-self-learning) | The standard both tools are held to after a mistake, the records it runs on with a real row from each, and how each record feeds the next |
| [Receipts](../evals/README.md) | Every open-source target with its outcome, the merged patches, the greenfield builds |
| [Contributing](../CONTRIBUTING.md) | The validator and the review bar |
| [White paper](https://github.com/lenamonj/jeffy-loop/raw/main/docs/The-Jeffy-Loop.pdf) | The full argument, written for readers new to agent loops |

## Recursive self-learning

A mistake is allowed once.

Jeffy Loop and [Housebroken](https://github.com/lenamonj/housebroken) are run by an agent, and an agent makes mistakes. So do the people who direct it. We do not expect a run with no misses. We expect a miss to be written down the day it happens, traced to the exact step where the work left its plan, and answered with something that would have stopped it. Then we expect never to meet that miss again.

This section is that standard, the records it runs on, and a real row from each record. Every row names the file it came from, so nothing here has to be taken on trust.

### What we hold ourselves to

1. **The record outranks recall.** A cause nobody can point to in a file, a commit or a thread is a guess, and it is labelled as one.
2. **Fix the loop that produced the miss.** A patch to the one run closes the symptom. The work is finished when the process that allowed the miss has changed.
3. **A lesson a machine can check becomes a check.** Prose is the weakest tool we have. A run once promoted a lesson into its plan and broke that same lesson two iterations later ([How it works](how-it-works.md#the-loop-improves-the-loop)).
4. **A check has to be able to fail.** A new check is accepted after it has been seen red, on the original defect or on a mutant. A check that has never failed has proven nothing yet.
5. **The author does not judge the work.** A second agent with no part in the run grades it. A maintainer, or anyone outside, outranks both.
6. **Failures stay on the record.** [`evals/ATTEMPTS.md`](../evals/ATTEMPTS.md) lists every target ever started, the ones that did not converge included.
7. **A person or a model is never the root cause.** "The session forgot" is where the questions start. The answer names a missing check, a tool that did not print a fact, or an action that had no sanctioned path.
8. **A person decides.** The loop finds, proves and proposes. A human in the loop rules on every change to the engine ([Recursive self-improvement](recursive-self-improvement.md)).

### The records, and a real row from each

Nobody is asked to remember to write most of these. The engine and the gates write them as a side effect of running.

| Record | Who writes it, and when | A real row |
|:---|:---|:---|
| Turn record, `.jeffy/metrics/<run>.jsonl` | The Stop hook, at every turn end | Run `b78c8d86-045240`, iteration 1: `"iter_type":"AUDIT"`, `"rows_unswept":21`, `"wall_elapsed_s":1362`. Iteration 2: `"rows_unswept":1`. |
| Fire log, `.jeffy/metrics/<run>.fires.tsv` | The Stop hook, each time it states one of its rules | The same run: `1794372952  1  lint  inventory-row-stale`, then `1794375646  2  lint  backlog-open-high-medium` |
| Evaluator report, `.jeffy/evaluator/<run>-<n>.md` | A second agent, each time a run calls itself done | `path-to-regexp`: three runs, five evaluator invocations, four rejections, and every rejection was a defect in the run's own evidence ([How it works](how-it-works.md#the-loop-improves-the-loop)) |
| Attempts table, [`evals/ATTEMPTS.md`](../evals/ATTEMPTS.md) | Derived from the run journals | `BurntSushi/toml`: 5 runs, 52 iterations, not converged, 3 runs ended blocked |
| Lessons in a project's `PLAN.md` | The run that learned the lesson | A lesson met a second time is marked `[recurred]`, and the run report proposes turning it into a mechanism |
| Lessons ledger, Housebroken [`docs/lessons.md`](https://github.com/lenamonj/housebroken/blob/main/docs/lessons.md) | The session, the day a maintainer rules | 2026-11-18, `mholt/PapaParse #1133`: an account with no role in the repository found a real defect in a pull request of ours that had been open since 2026-07-27 |
| Refusal log, Housebroken, local to each machine | Every gate, each time it says no | A UTC time, the permanent name of the rule and the repository. It holds no message text and never leaves the machine. |

The two engine rows can be printed from a clone of this repository:

```bash
cat .jeffy/metrics/b78c8d86-045240.fires.tsv
bash scripts/jeffy-stats.sh . --rules
```

### From a miss to a mechanism

These are real conversions, each quoted from the file named. Left to right: what went wrong, who caught it, what it became, and how the new mechanism was shown able to fail. Where the record does not say, the cell says so.

| When | What went wrong | Caught by | What it became | Seen red |
|:---|:---|:---|:---|:---|
| 2026-11-18 | `mholt/PapaParse #1133`: a fix added state that lives between calls and was tested through one arm of the choice it changed. The same code stood in a second place and was left alone. | An account with no role in the repository | `housebroken sites` lists every other place the base holds the code a branch replaces. The review brief attacks those places and any state carried between calls. | Its test kills 26 of 26 mutants |
| 2026-11-18 | That new check went to its review with a green suite | Our own review: "DO NOT SHIP". "nine of sixteen mutants of same-code.sh pass the shipped test" | A new gate is reviewed like a patch, and the review mutates it. The release note says how many mutants the test kills. | 26 of 26 after the fix |
| 2026-11-18 | The script that writes a merge receipt staged one wrong, then red. 195 unit tests passed both times: they held the script's model of the page and not the gate's. | The fresh-clone validate: "count:issues claims 4 but the scorecard derives 3" | A test reads the gate's own label counts and fails when the script derives fewer | On the old script it names `issue filed` |
| 2026-11-08 | Three pull requests were withdrawn by hand: no check on the note, the fork branches left up, nothing recorded | Not stated in the ledger | `close.sh` is the only way a pull request of ours is withdrawn | Not stated in the ledger |
| 2026-11-07 | Two replies were drafted for accounts with no role in the repository, and one was posted. The inbox printed no role beside a commenter. | The user | The inbox prints each voice's role, and `reply.sh` refuses a voice with no role without the user's word | Not stated in the ledger |
| 2026-11-01 | "a check that read nothing looked exactly like a check that found nothing", twenty times | An independent review, in which 12 of 27 mutants survived | A scan proves it read something before it may pass: UNREAD, never CLEAN, in every gate | Not stated in the ledger |
| Earlier, in Jeffy | A published number was copied from wherever it last appeared | Not stated on that page | Check K compares the published check count with the validator run itself, on every host | During a release build it rejected a stale `203` that a human had already read past |
| 1.29.0, in Jeffy | A run ending stated its rule and recorded nothing | The first self-run over the change that gave every rule a name | The fix, and the checks that now hold it | Not stated on that page |

The Housebroken rows are from its [lessons ledger](https://github.com/lenamonj/housebroken/blob/main/docs/lessons.md). The Jeffy rows are from [How it works](how-it-works.md#the-loop-improves-the-loop).

### The ladder

Every countermeasure is rated by how much it depends on someone remembering. We build at the highest rung we can reach.

| Rung | Mechanism | On the record |
|:---:|:---|:---|
| 1 | Remove the possibility. The value is derived, so nobody types it. | Check K: the published check count is held to the validator run |
| 2 | A gate that refuses and fails closed | `close.sh`, the only way a pull request is withdrawn |
| 3 | A behavioural check or a test, proven by sabotage or mutants | The checks in `scripts/validate.sh`; the receipt test that reads the gate's own counts |
| 4 | A tool that reads for you and prints what has to be decided | `housebroken sites`; the inbox printing each voice's role |
| 5 | A line in a prompt, a review brief or a checklist | The review brief items on other sites and carried state |
| 6 | Prose: a lessons row, a `PLAN.md` Lesson, a note | Where every lesson starts, and where none should stay |

A gate or a test with no record of having been seen red is counted at rung 6 until it has one.

### How the records feed each other

| From | To | What carries it |
|:---|:---|:---|
| A run | Turn record, fire log, journal entry | The Stop hook, at every turn end. The journal heading supplies the record's `iter_type`. |
| Fire logs | Which rules fired, on which path, and which never fired | `scripts/jeffy-stats.sh --rules` |
| A run that calls itself done | An evaluator report | A second agent with no part in the run. A rejection sends the run back to work. |
| Run journals | `evals/ATTEMPTS.md` | Derived, failures included |
| A defect found in the engine | A behavioural check in `scripts/validate.sh` | The fix lands with a check that fails if the defect returns |
| The validator run | The check count this repository publishes | Check K refuses a page that promises more checks than the run delivered |
| A maintainer's verdict | A lessons row, then a gate | Quoted verbatim the same day, with the rule it became |
| A gate that says no | The refusal log | One line per refusal, under the rule's permanent name |
| A lesson met twice | A proposal to mechanize it | The `[recurred]` mark. A person decides. |
| All of the above | A review of what left its plan | For each miss: where it started, which checks let it through, and what will stop it next time |

### Measured, not believed

"Is it working" is a number or it is nothing.

- The count of behavioural checks began at 119. The [README](../README.md) carries the current floor, and check K holds that number to the validator run.
- The [receipts](../evals/README.md) list every merged patch, and [`evals/ATTEMPTS.md`](../evals/ATTEMPTS.md) lists every target that did not converge.
- The review in the last row above is new. As of 2026-11-19 none has run. From the first one on, it reports for each window: how often a closed cause came back, the share of misses first found by someone outside, the time from a miss's origin to its detection, the share of countermeasures at rungs 1 to 3, and the share with a recorded red proof. Those numbers go here once there are two reviews to compare. Until then this section claims no trend.

Jeffy would rather be measured than believed.
