# Recursive self-improvement (RSI) in Jeffy

<div align="center">

<img src="../media/quote-audit.png" alt="A dark card with a gold foil seal and gold lettering: Improvement compounds. So does error. The difference is the audit." width="760">

</div>

In 1965 the mathematician I. J. Good described a machine able to design a better machine than itself, and called what would follow an "intelligence explosion".[^good] Recursive self-improvement (RSI) is the name that idea goes by now: a system that is both the thing being improved and the thing doing the improving.

Jeffy runs almost the whole of that cycle on its own engine. It audits itself, writes the fix, proves the fix with a check, and has a second agent try to reject the work. The last step it leaves out on purpose: a human in the loop makes every final decision on what changes. This page says what each of those claims rests on.

## The closed loop

In an RSI loop the system finds its own weak point, changes itself, tests the change and runs the new version. Jeffy does that to its own source:

1. Jeffy is pointed at this repository under the same rules as any outside project: the same evidence rules, the same adversarial gate, no privileged mode.
2. A finding counts only when a check that runs proves it.
3. A defect in the engine is fixed with a behavioural check in `scripts/validate.sh` that fails if the defect returns.
4. A second agent with no part in the run tries to reject the result before the run may call itself done.
5. The engine that comes out is the engine that audits the next round.

Release 1.29.0 is a worked case. A self-run over the change that gave every rule a name found a run ending that stated its rule and recorded nothing, fixed it, and added the checks that now hold it. [The loop improves the loop](how-it-works.md#the-loop-improves-the-loop) has the earlier cases and their commits.

## A human in the loop

Jeffy stops one step short of closing the loop, and that is the design. Everything up to the decision is automated. The decision is not.

| Step of the cycle | Who does it |
|:---|:---|
| Find the weak point in its own engine | Jeffy |
| Write the fix | Jeffy |
| Prove the fix with a check that runs | Jeffy |
| Try to reject the work | A second agent with no part in the run |
| Record which of its own rules fire | Jeffy, from 1.29.0. [Usage](usage.md) has the fields. |
| Decide that a change to the engine ships | A human in the loop, every time |

Nothing acts on the fire log by itself either: the loop counts, and a person decides what to do about a rule that never fires. The model is outside the cycle altogether. Jeffy does not train it or alter it; the engine around the model is what improves.

## The guardrails

A loop that improves itself can learn to grade itself kindly, and it can move faster than anyone reads. Those are the two real risks, and each has a mechanism here.

- **The judge is not the author.** A standard run is complete only when a second agent with no part in it signs off, and that agent grades the run's evidence as well as the code.
- **Published numbers answer to the run.** The check count this repository publishes is compared with the validator run itself, and a page that promises more checks than the run delivered is refused.
- **Failures are published.** `evals/ATTEMPTS.md` carries every attempt, the ones that did not converge included, and a self-run that fails to converge is merged under a subject that says so.
- **The loop never pushes.** It commits locally, and nothing becomes a release until the human in the loop approves it.

## What this is not

It is not an intelligence explosion. Nothing here trains a model or makes one smarter. The gain is an engine that forgets less after every run, held by a test suite and released by a person. Good's own condition for his machine was that it stay docile enough to tell us how to keep it under control. Jeffy's version of that condition is plainer: it would rather be measured than believed.

[^good]: I. J. Good, "Speculations Concerning the First Ultraintelligent Machine", *Advances in Computers*, vol. 6, 1965, pp. 31-88.
