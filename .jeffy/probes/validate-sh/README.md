# validate-sh

The harness is the oracle. Every `[x]` in the Surface inventory, every entry in
the Derived and settled sections, and every count a journal entry quotes stand
on `All checks passed`. That sentence is a claim about `scripts/validate.sh`,
and a green run can never falsify a claim about what the harness cannot see -
so the file that grades the whole tree was the one file nothing graded. Run the
coverage command the Oracle class line names and `scripts` is not among the
zeroes, but what the harness says about `scripts/` is said about the media
renderers; nothing in it reads itself.

## Two scripts, and the reason

`run.sh` holds the static arms and runs in seconds. `suite.sh` holds the arms
that need a real run of the harness, and one invocation costs a full suite.

That split is cost, stated rather than silent. Putting the executed arms in
`run.sh` would make the battery too slow to run per-iteration off its `paths`
file, and putting them in `claims` would cost two full suites at every
`check-claims` pass - which the gate runs at every declaration. So a sweep of
the row runs `suite.sh` and records its output on the row; `check-claims`
executes the static arms and the mutations that drive them.

`suite.sh` needs its memory ceiling raised past `run-probe.sh`'s 4096MB
default, because check 5 runs `shellcheck -x` over this tree and that peaks
near 10GB. Under the default the probe is killed, and the wrapper names the
wall ceiling rather than the memory one - filed as J13, which is a defect in
shipped runtime rather than in this battery.

## What run.sh establishes

**The check-region partition.** A check is a comment block opening with its own
id. The id grammar alone over-matches, because a wrapped comment whose sentence
breaks at a word followed by a period reads identically; the discriminator is
positional - a header opens a block, so the line before it is not a comment.
The rule is proved on a known positive and a known negative in a fixture before
its silence counts, and both populations are reported, because a rule that
rejects nothing is a rule nobody needed.

**That no check can stop being able to go red.** Every region that reports at
all carries both a `pass` and a `fault` site, in both directions, and the only
region that reports nothing is named rather than tolerated as slack. Partition
completeness is asserted first - the per-region sums equal the whole-file
counts - because without it the pairing arms are about whatever the partition
happened to see.

**That the counters cannot be written from anywhere else.** `pass`, `fault` and
`skip` each print a line and move a counter together, and the summary is
computed from the counters alone, so a check that clears the failure flag hides
every earlier failure and one that bumps the pass counter publishes a pass
nobody printed. The writing sites are counted as occurrences and not as lines:
`grep -c` counts lines, so a third writer appended to a line that already
assigns the counter would be invisible to the arm written to catch it.

**That the green line is the line the loop reads.** `PLAN.md` states the
`Verify summary pattern` the wrapper greps this line with, and `PLAN.md` is
gitignored here, so no harness check can read it. The green line is extracted
from the harness and rendered rather than retyped beside the pattern - a
literal written here would compare the pattern against this battery's idea of
the line, leaving both green when the harness renames it. That is this
project's own `[recurred]` Lesson about a mechanism the engine ships and this
repository never declares.

**That a skip stays honest.** Each one states its reason in a parenthetical,
which is the set the Environment fingerprint derives its gate list from, and
none is unconditional at the top level.

**The sandbox partition, two arms of which are labelled `known gap:`.** The
harness builds its sandboxes with `mktemp -d` and the trap at the head of the
file exists so an aborted run does not leak them. Three sets decide whether
that holds: the directories created, the ones the trap covers, and the ones
removed on the normal path. The partition is pinned as it stands, and the two
arms covering the sandboxes outside the trap carry `known gap:` labels because
the state they pin is wrong rather than intended - filed as J12, not hidden
here. A fix turns those arms red in the same iteration, deliberately, and the
`claims` file drives exactly that.

## What suite.sh establishes

A real run, in a detached git worktree at `HEAD` rather than a `cp -a`, because
checks here read the git index, derive their file list from `git ls-files` and
walk tracked artifacts - a stage without `.git` would skip or fault for reasons
no mutation caused. The baseline is re-run on the stage itself before any
mutation verdict is read.

The arm worth the most is the accounting one, and it covers a population no
static read can reach: the printed `[OK]` and `[SKIP]` lines are counted and
compared against the counts the summary line reports. A `pass` or `skip` that
executed inside a command substitution or a pipeline subshell prints its line
while its counter stays behind, and a `fault` that did so prints `[FAIL]` while
the run still exits 0. One observation tests that for every reporting site in
the file at once. A population floor sits beside it, because equality between
two numbers both derived from an empty capture is satisfied by nothing having
run at all.

Beside it: exactly one summary line, the green one on a clean run with exit 0,
and the graded tree left clean by `git status --porcelain` - the harness grades
a tree and must not write to it, or the next checkpoint's `git add -A` ships
whatever it left.

With a mutation, the red direction: exit 1, at least one `[FAIL]`, the green
summary absent, and the expected check named. A staged shell file is checked to
parse and to differ from the shipped one before its verdict is read, because a
suite faulting on a file that no longer parses is indistinguishable from a
suite discriminating the check the mutation removed.

## What it cannot reach

Nothing here re-derives what the checks assert; the arms are about the shapes
in which a check stops being able to report, not about whether its claim is
right. Per-check discrimination is established only for the checks a recorded
mutation falls, and the rest rests on the structural arms - an honest bound,
and the reason the mutations chosen are behavioural ones against the engine
rather than static marker reads.

`suite.sh`'s results are recorded on the Surface inventory row and in the
journal entry rather than in a `claims` line, for the cost reason above, so
they are re-executable by hand and not by `check-claims`.

The partition reads the file's own comment grammar, so a check written without
a header is invisible to every arm that walks regions - it would still be
counted by the whole-file totals, and partition completeness is what makes that
discrepancy visible rather than silent.
