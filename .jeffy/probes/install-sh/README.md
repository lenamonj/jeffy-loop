# install-sh

Known-answer battery for `install.sh`, the shell installer. It is one of the
two shipped paths that put the engine on a machine, and PLAN.md's row for the
Python console script states the premise both rows share: the same contract is
implemented twice, in two languages, and the two can drift without either one
breaking.

`install.sh` resolves its payload from its own directory, so the file under
test and the skills it copies always come from one tree. `JEFFY_PROBE_ROOT`
selects that tree, which is what lets a mutation be staged beside a copy of
`skills/` and driven as the real installer.

## What it drives

Every documented outcome against a sandbox `HOME`: a fresh install lands both
skills and the hook, registers once at 1800s, leaves every hook script
executable, and prints the success line; a second run reports "already
registered" and adds nothing.

The registered `timeout` is a documented parameter with three values leading to
three outcomes, and all three are driven: absent and `600` each upgrade to 1800
and say so, `1800` is left alone, and each upgrade is re-run to confirm it
happens once rather than every time.

The registration count and timeout are read out of `settings.json` with `jq`
rather than off the installer's printed line, because the message is what the
installer claims and the file is what Claude Code will read. An install over a
dead foreign registration must remove it, keep an unrelated Stop hook, keep an
unrelated hook event, and keep an unrelated top-level key - all four asserted
from the file.

**The prune's read-back is the part worth the most.** Four substitutions stand
between the prune and deleting a live registration - `~`, `$HOME`, `${HOME}`
and an escaped `\$` - and each is driven with a command that really does name
an installed hook. A read-back that failed would make the installer call its
own work dead and re-add it, leaving two registrations where there should be
one, so the arms assert the count and the absence of the "does not exist" line
together.

The settings file is driven in every shape it can be in: absent, valid,
whitespace-only (which the installer replaces with `{}`), invalid JSON (which
must be reported and left byte-identical, with the skills still installed and
no temp left behind), a symlink (written through at its target, with the link
intact and the user's other key preserved), and inside an unwritable directory
(which must print which directory and what it left alone, rather than dying
under `set -e`).

`jq` absent is a documented degradation rather than a crash: the skills still
land, the skip and the missing-prerequisite lines both print, no
`settings.json` is written, and the exit status is 1. A copy of the script with
no payload beside it refuses and names where to run it from.

## What it was observed failing on

Recorded at creation; each is replayed by a line in `claims`, each stages a
full copy of `skills/` beside the mutated script, and each is confirmed to
parse and to differ from the shipped file first.

- Dropping the `${HOME//\$/\\\$}` escaping from `hook_cmd`.
- Dropping the `${HOME}` substitution from the prune's read-back, which makes
  the installer report a live registration as dead.
- Deleting the `readlink -f` symlink resolution, which replaces a linked
  `settings.json` with a regular file.
- Deleting the stale-file `rm`, which leaves a file the shipped tree no longer
  carries installed.
- Deleting the `-exec chmod +x`, which leaves all six hook scripts
  non-executable after an upgrade from a release that shipped them at 644.
- Weakening the upgrade predicate to `has("timeout")`, which leaves a 600s
  registration at 600s - the exact shape P1-58 exists to move.

## Four of its own arms were wrong first

Worth recording, because each failure read like a defect in the installer:

- The `jq` expression reading the preserved keys used `[X | length, Y, Z]`,
  which jq parses as `[X | (length, Y, Z)]`, so `.hooks` was applied to an
  array and the whole arm errored.
- The bare-path form was fixtured with a path that does not exist, so the prune
  correctly removed it and the arm asserted the opposite of what it meant.
- The unwritable-directory arm locked `~/.claude` before the first install, so
  the skills copy failed and `set -e` ended the run before the settings block
  was ever reached. The skills are now installed first and the directory locked
  after.
- The no-`jq` arm set `PATH` to a directory holding only `claude`, which also
  hid coreutils; the installer died at 127 before reaching the branch under
  test. The needed binaries are now symlinked in by name with `jq` left out,
  and the arm skips if any cannot be resolved or if `jq` is still reachable.

A fifth defect was in the skip guard rather than an arm, and it is the one
worth generalising: the unwritable-directory arm decided whether the mode had
taken by reading the installer's exit code. A mutation to the upgrade predicate
also changed that exit code, so those three arms silently left the tally and
the battery reported 61 of 64 with no failure - the same shape as the
command-substitution defect in the packaging battery. The guard now writes a
probe file into the directory and reads whether that succeeded.

## Section L and M: a settings.json its owner cannot write (J17)

These arms exist because the sections above drive each factor of a defect alone
and never their cross. Section H drives a whitespace-only settings file and
section I an unwritable settings *directory*; neither drove a settings *file*
the user cannot write, and that is the state in which both of this installer's
write paths failed. One of section I's own arms asserts that an unwritable
settings directory raises no shell error, and the whitespace-plus-read-only
cross falsified exactly that assertion while every arm stayed green.

A read-only `settings.json` is what a dotfile manager leaves behind - the
comment beside `settings_tmp` names that store, and the Python sibling's
comment names stow and home-manager - and replacing one is a rename, which
needs write permission on the directory rather than on the file. So it is a
state this installer must handle rather than refuse, and the Python sibling in
`src/jeffy_loop/cli.py` did handle it while this one did not.

What the arms pin, per fixture: a valid `settings.json` at mode 444 is
registered at 1800s with the user's other top-level key intact and the file
left unwritable; an empty one at 444 and a whitespace-only one at 444 are
seeded through the temp-and-rename path and registered the same way, reaching
the installer's closing summary; and none of the three leaves a temp behind or
puts anything on stderr. Section M reads this installer's stderr on the
ordinary path, which nothing here had ever done: a fresh install into a home
with no `settings.json` yet must say nothing at all.

Whether this filesystem honours a read-only file mode is tested directly, on a
probe file of the battery's own, never inferred from the installer's exit code
- section I records what inferring it cost. Root tests writable on everything,
so a root run skips these arms rather than reporting a failure it cannot
attribute, and that is also the one bound the fix itself carries: a 444
`settings.json` replaced by a root install comes back 644.

The mode is read with `test -w` rather than with `stat`, whose flags differ
between GNU and BSD userlands; what the claim is about is whether the file
stayed unwritable, not its exact bits.

The mutations recorded in `claims` for these arms, each confirmed to parse and
to differ from the shipped file first:

- dropping `chmod u+w "$tmp"` from `settings_tmp` restores the pre-fix order,
  where `cp -p` stamped the source's mode on the temp before the write; every
  read-only fixture then fails.
- replacing `chmod a-w "$tmp"` in `settings_mv` with a no-op leaves the
  replacement writable, and only the mode arm falls. Deleting that line instead
  was the first form tried and it does not parse - it empties its own `if` body
  - which is why the kept mutation substitutes rather than deletes.
- writing the seed's `2>/dev/null` after its output redirection rather than
  before it restores the leak, and the two read-only stderr arms fall.
- writing the `tr`'s `2>/dev/null` after its input redirection restores the
  leak a fresh install produced on every run, and section M alone falls.


## What it cannot reach

The differential against the Python console script is not an arm here, for the
same reason it is not one in `jeffy-loop-cli`: it would put `src/jeffy_loop`
into this battery's `paths` and stale this row on every console-script edit.
It is run by hand in whichever sweep touches both, and the result is recorded
on both rows - identical file trees with identical modes, an identical
`settings.json` and an identical stale-file message.

The interactive `jq` install prompts, the Homebrew and apt branches, are not
driven: they need a host without `jq` and a package manager to answer, and this
host has `jq`. The `[SKIPPED]` branch below them is what the no-`jq` arm
reaches. Nothing here runs the registered hook; the `stop-hook` battery owns
that.
