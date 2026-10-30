# stop-hook

Known-answer battery for `skills/jeffy/hooks/stop-hook.sh`, the engine itself,
covering the three Surface inventory rows scoped to that file: the fast paths
and identity, the converged-stop gates, and the re-feed path.

It drives **this tree's** hook, never the installed copy, with synthetic Stop
payloads against a throwaway git project, and asserts the observable outcome of
each case - the JSON decision, the state file's own mutation, the stderr
diagnostic and the exit status. Driving the tree's copy is the point rather
than a detail. Previous sweeps drove the installed hook while the row they
recorded names the tree path, which was harmless only for as long as the two
were byte-identical; in a checkout that develops the engine they routinely are
not, and the row would then certify a file nothing had exercised.

What it covers, by row:

- Fast paths and identity: a project with no state file is a silent no-op at
  exit 0 with empty stdout; a state file naming a foreign session draws no
  decision and is left byte-identical; the owning session with budget left
  returns `decision: block` and advances the counter; a counter reading a
  non-number fails open rather than crashing.
- Re-feed path: the run state names the iteration the model is about to
  perform rather than the one on disk; exhausting the budget with work still
  open ends the run and deletes the state file; exhausting it with nothing
  above Low left grants the one-time `+2` instead and re-feeds past the budget.
- Converged-stop gates: a promise over a project with no PLAN.md is refused;
  the ledger severity floor refuses an open Medium; the inventory gate refuses
  an unswept row; a promise with no Converged line naming a commit is refused;
  and a fully formed declaration - swept map, empty ledger, AUDIT and closing
  entries under the run's own id, a committed evaluator artifact ending in
  `Verdict: PASS`, and a reachable Converged hash - is accepted.
- V1 specifically: the gate accepts a map whose only extra rows are the
  grammar examples a PLAN.md writes to document its own row forms, and the run
  state counts none of them as unswept, which is two of the four readers the
  fix routes through one filter. The control holds the fix narrow from the
  other side: an indented row naming a *real* surface is still a row, counted
  by the run state and refused by the gate.

## Discriminating inputs

Recorded at creation. Each was applied to the shipped hook, run, and restored
with `git show HEAD:<path>`, with the tree confirmed clean afterwards.

- The hook restored to its pre-V1 generation at `675d9a7`: the two V1 cases
  fault and nothing else does, the run state reporting `unswept rows 1` where
  the map holds none.
- The foreign-session guard reduced to its empty-field half: the hook answers
  a session that does not own the run and rewrites its state file.
- The re-feed counter assigned the current iteration instead of the next: the
  counter never advances, and the run-state and closing-extension cases fall
  with it.
- The severity floor's `(Low` anchor widened to `(`: every open task reads as
  a Low and an open Medium stops blocking a declaration.
- The inventory gate's unswept test replaced with a constant false: both the
  unswept-row refusal and the indented-real-row control fall together, which
  is the pair that shows the control is testing the gate rather than the
  parser.

Three of these run as claims lines beside this file, so
`skills/jeffy/hooks/lib/check-claims.sh` re-establishes them rather than
trusting this list.

## What the battery itself got wrong first

Recorded because a probe believed at face value here would have filed three
findings against entirely correct code - the same trap a previous sweep of
these rows fell into and recorded. The first draft asserted that exhausting
the budget always ends the run, which is only true while work is open; with
the ledger at the severity floor the hook correctly grants the closing
extension instead. The second and third were one cause: the fixture journal
was headed with a run id the fixture's own session never produces, and the
gate refuses a declaration whose closing entry it cannot find, so two gate
cases failed for a reason that had nothing to do with the gate under test. A
fourth followed once those were fixed - the fixture carried no AUDIT entry,
which a declaration also rests on.

## Running it

    bash .jeffy/probes/stop-hook/run.sh [tree-root]

Exit 0 and one summary line when every known answer holds, 1 with the
disagreements, 2 when the host has no jq or no git, without which no fixture
here can be built.
