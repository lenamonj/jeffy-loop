# references

Known-answer battery for `skills/jeffy/references` - the iteration prompt the
engine feeds at every turn end, its High-hunt sibling, and the templates a
launch copies into a target project.

These files are product the engine executes rather than prose about it. The
hook reads the prompt from disk and re-feeds it verbatim; the launcher's mode
guard reads the first word of `plan-default.md`'s Mode section; the hook parses
`plan-default.md` by labelled line and `backlog-default.md` by section
heading. PLAN.md's own Lessons record the failure this guards: a template that
loses a line the hook reads makes the hook silently skip the converged-stop
check that line feeds, and nothing goes red.

## What it drives

The shipped set is derived from the directory and asserted whole, so a file
added or removed reaches this battery rather than passing unnoticed.

Each prompt is required to hold no newline and no CR and to be non-empty. The
newline property is the one shape that breaks the re-feed, since the hook
JSON-encodes the file and hands it back as a single prompt.

Each prompt is required to name its own promise phrase and *not* the other's,
in both directions - a hunt prompt that still said `JEFFY CONVERGED` would let
a hunt declare a convergence it never earned.

The two mode words the launcher's guard refuses on are read as the values they
are: `Improvement.` and `High-hunt.`.

Every labelled line the hook parses out of `plan-default.md` is required
present, and the Verify half of that set is required to survive into
`plan-highs.md`, because a hunt runs the same gate. Every ledger section the
hook's section parser walks is required present in the template that owns it,
and absent from the one that does not: `backlog-highs.md` carries no
`## Converged` and no `## Next`, `backlog-default.md` carries no `## Hunted`.
Both directions, since asserting presence alone would pass a template that
carried every section indiscriminately.

The journal grammar is read as the template really writes it - angle-bracketed
placeholders, a pipe-separated status set - and both of its enumerations are
asserted, including that the status set still carries `hunted`, which only the
hunt's closing entry uses and which a standard-only edit could quietly drop.

## The prompt pair, derived rather than asserted

`skills/jeffy/SKILL.md` says the hunt prompt "is the standard prompt with the
convergence machinery deleted so every shared sentence stays byte-identical".
That sentence quantifies over a set and nothing in this tree derived it. The
last arm derives the partition and reports it: the standard prompt's sentence
count, the hunt's, how many hunt sentences are byte-identical to a standard
one, how many are not, and - the only one asserted at a value - how many
differing sentences still carry convergence machinery, which must be zero.

The partition is a measurement and lives in `claims`, not in this file, because
it moves with every edit to either prompt. What it showed on its first run is
why J11 is on the ledger: most hunt sentences are *not* byte-identical,
because the machinery was removed from inside sentences rather than by deleting
whole ones. Each difference inspected was convergence or Surface-inventory
text being removed, so the claim's intent holds while its wording does not.
The arm asserts the half that is true and load-bearing - no hunt sentence
carries convergence machinery - and measures the half that is merely a
consequence of how the deletion was done.

## What it was observed failing on

Recorded at creation; each is replayed by a line in `claims`, and each stages a
full copy of the directory and is confirmed to differ from the shipped one.

- Appending a newline to `iteration-prompt.txt`.
- Changing `plan-default.md`'s mode word to the hunt's.
- Deleting the `Verify summary pattern:` line from `plan-default.md`.
- Deleting `## Hunted` from `backlog-highs.md`.
- Appending a sentence naming the evaluator gate to the hunt prompt, which the
  convergence-leak arm reports.
- Removing `hunted` from the journal grammar's status set.

Two arms of this battery were wrong on their first run and both were the same
mistake: they searched `journal-default.md` for the way the *iteration prompt*
phrases the grammar rather than the way the template writes it, and both
returned 0 - which reads exactly like a template that had lost its grammar
line. They now read the template's own shape, and the grammar line is extracted
once and both enumerations asserted against that extraction.

## What it cannot reach

Nothing here runs the hook against these templates; the arms assert that the
lines and sections the hook reads are present, not that the hook then behaves
correctly over them - the `stop-hook` battery owns that. The templates' prose
is not graded at all beyond the labelled lines and headings named above, and
the `Imported governance mechanisms` command in this project's own PLAN.md is
the instrument for whether this repository's fork of `plan-default.md` has
kept up with it.
