# quiet-verify

Known-answer battery for `skills/jeffy/hooks/lib/quiet-verify.sh` in both of
the roles that file has on purpose: sourced, where `stop-hook.sh` calls its
bound resolver and its pipefail predicate, and executed, where the loop runs it
instead of the raw Verify command.

Every arm builds its own throwaway PLAN.md and asserts the documented outcome
by its exit status and its stderr, with stdout captured apart because silence
on stdout is this file's whole reason to exist rather than a side effect.

What it drives, by contract state: `Command: none`, an empty Command, the
template placeholder, a command that merely carries a redirect pair, a section
with no `Command:` label, a missing PLAN.md, a pre-1.8.0 PLAN.md carrying
neither the Oracle class nor the Environment fingerprint, an `Oracle class:`
label with nothing after it, a green command, a green command with a summary
pattern, a red command, and a command past its bound.

Documented labelled lines are driven at values that must disagree rather than
at one value each. `Verify output budget` at 300 and at 2 over the same
six-line failure changes how much tail reaches stderr. `Verify summary pattern`
present and absent changes the green stderr line and decides whether
`.jeffy/metrics/verify-last.json` is written at all. The bound ladder is driven
at every rung: an explicit state value, a measured `Verify duration` at three
times itself, a small measurement floored at 240, no measurement at all, an
explicit `0` read as unset rather than as no limit, a leading zero read as
decimal rather than octal, and a value past the cap the registration can
honour, which clamps and says so where it happens.

## What it was observed failing on

Recorded at creation. Each mutation was staged aside under `.jeffy/scratch` and
pointed at with `JEFFY_PROBE_ROOT`, and each staged file was run through
`bash -n` before its verdict counted, because a file that no longer parses
faults the battery in a way indistinguishable from a guard being removed.

- Restoring the pre-A2 unanchored placeholder arm, `*'<'*'>'*`, makes the
  redirecting command be refused at exit 2 as an unfilled template. That is the
  defect A2 closed, and it reproduces here with the message naming the wrong
  cause.
- Removing the `(^|[^|])` anchor from the pipefail predicate makes
  `make test || grep -q ok log` answer `+o`, where the shipped file answers
  `-o`. The engine's answer is the one this battery pins, which is what the
  open ledger item about the converged stop's own re-typed copy of that pattern
  rests on.
- Removing the clamp lets the bound resolve past the cap, and the stderr notice
  disappears with it.
- Making the green path print anything to stdout fails the two arms that assert
  the silence.
- Removing the section scope from the labelled-line reader makes a `Command:`
  line under `## Lessons` win over the real one, which is the defect P1-59
  closed.

## What it does not cover

The watchdog path is driven only through the timeout arm, which binds at one
second and reports 124. Whether the kill reaches a whole process group - the
`set -m` and `kill -- -$pid` pair added in 1.27.0 - is not asserted, because
the fixture's command has no children to orphan. A battery that pins it needs a
Command that spawns one and outlives its parent, and writing that is work this
battery leaves named rather than done.
