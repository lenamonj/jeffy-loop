# docs battery

Known-answer battery for `docs/` - the four published pages `README.md` links.

## Why this surface earns an instrument

Two of these pages are not prose about the engine. `docs/headless.md` publishes
a bash driver and a PowerShell driver that a user copies into a shell and runs
unattended; `docs/usage.md` publishes the flag set the launcher accepts, and the
launcher refuses an unrecognised `--` token, so that set is closed in both
directions. This project's own Publication rule says code leaving the project is
run in exactly the form it is published - and nothing in the tree ran these.

`scripts/validate.sh` check 10 extracts and `bash -n`-checks every fenced bash
block in `skills/jeffy/SKILL.md`. It has no sibling for `docs/`. What the
harness does read of these pages is narrow and enumerable with
`grep -nF -- docs/ scripts/validate.sh`: the `count:` markers checks J and K
derive, the single `--max-surface` name check K4 greps for, and the timeout
chain checks M and P read out of `how-it-works.md`. The driver scripts, every
relative reference, every heading anchor and the flag set itself were outside
all of it.

## What it drives

- **The published set and the fenced inventory.** The page set is read off the
  directory and asserted whole; the bash and PowerShell block counts per page
  are asserted too, because every arm below indexes into those blocks and a
  page that gained a third block would otherwise leave the new one unparsed
  while everything already written still passed. Fence balance is asserted per
  page, since an odd count swallows the rest of the page into the previous
  extraction.
- **Every published bash block parses.** Three properties per block rather than
  one: the extraction is non-empty, `bash -n` exits 0, and its stderr is empty.
  The non-empty guard is load-bearing - an extractor returning nothing hands
  `bash -n` an empty script that parses clean. The stderr read is there because
  `bash -n` accepts an unterminated here-document with only a warning, which is
  the same reason check 10 reads it for the skill.
- **The bash driver runs as published.** It is copied out of the page, never
  retyped, and executed under `env -i` with `HOME` pointed at a sandbox so the
  block's own `TARGET=~/targets/itoa` resolves there and a stub `claude` on
  `PATH` produces each documented outcome. All three the page promises are
  driven: budget spent, no progress, and converged. The stub's invocation count
  is asserted beside each message, because a loop that exits on its first pass
  prints the same budget-spent line as one that ran every round.
- **Every relative reference and anchor resolves.** These pages sit one
  directory below the root and link upward (`../README.md`), sideways
  (`usage.md`) and inward (`#anchor`). Each reference is carried with the page
  it was found on, because a bare `#anchor` resolves against its own page and a
  list that lost the page cannot tell which one that is. The populations are
  asserted as well as the miss list: nought references examined would empty
  that list for the wrong reason.
- **The flag set.** What `usage.md`'s synopsis publishes is compared against
  what the launcher skill's `## Arguments` section defines, both extractions
  asserted non-empty first. The two surface ceilings are compared digits-only,
  since `usage.md` writes them with thousands separators.
- **The PowerShell driver, honestly bounded.** No host here can parse
  PowerShell, which the Environment fingerprint records, so this is not a sweep
  of that block and no arm claims it is. What is asserted is that the twin still
  states the same three outcome messages the bash half was executed against, so
  the pair cannot drift while only one of them is runnable. The battery prints a
  `NOT RUNNABLE` line naming what would cover it, in the shape its sibling
  `media-render` uses rather than the raw-traceback shape `flowchart` uses.

The expected total is written at the head of `run.sh` and worked out from the
arms before the run, never read off a green one: a helper that loses checks to a
subshell reports a smaller total with no failure at all, which this project has
now been bitten by twice.

## Seen to fail

The `claims` file records each mutation and `check-claims.sh` re-executes them,
so the discriminating power is re-derivable rather than asserted here. Every one
was staged on a full copy and confirmed to differ - and, where it changed a
fenced script, to still parse - before its result counted. What they move: a
relative reference retargeted at nothing; an anchor naming no heading; the
driver's no-progress `exit 1` turned into `exit 0`; its `accepted()` pattern
pointed at a verdict that never appears; a flag added to the launcher's
arguments; a flag dropped from the published synopsis; and the round loop
rewritten to run once while `ROUNDS` stays 3.

That last one is the isolating mutation worth naming. It leaves `ROUNDS=3`
alone, so the budget-spent *message* still prints correctly and only the
invocation count falls - which is the whole reason the count is asserted beside
the message rather than the message alone.

## What it cannot reach

- Nothing parses or executes the PowerShell driver. The Windows CI leg is the
  only place that could, and it does not do it either.
- The driver is executed against a stub `claude`, so what is established is the
  driver's own control flow and messages, never that `claude -p` behaves as the
  page describes. A round whose `claude` exits non-zero is also not driven: the
  block runs under `set -euo pipefail`, so that would abort it before the
  no-progress diagnostic the page documents, and no evidence here says whether
  `claude -p` ever exits that way.
- The `git clone` block is parsed and not run; cloning two third-party
  repositories is not this battery's business.
- The prose of these pages is not graded. Where a page states an engine
  mechanism, the check that derives it is named above and lives in the harness.

## Instrument defects found while writing it

One, and it is recorded here rather than quietly fixed because it read exactly
like the battery being wrong. The first mutation run staged a root holding only
`docs/` and `skills/jeffy/SKILL.md`, so every `../` target was legitimately
absent and the reference arm reported misses that had nothing to do with the
mutation - burying the real detection among them. A stage has to be faithful to
the surface the arm walks, which is what `stage.sh` now is, and the baseline is
re-run on the stage itself before any mutation result is read.
