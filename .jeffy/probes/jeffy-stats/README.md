# jeffy-stats battery

Known-answer battery for `scripts/jeffy-stats.sh`, the maintainer telemetry
reader that aggregates the Stop hook's per-turn JSON records.

## Why this row needed a different kind of evidence

This is a surface that **computes values**, and PLAN.md's own rule for such a
row is explicit: a probe is a correctness check and not a liveness check,
because wrong numbers returned without complaint survive every liveness probe.

The row's previous evidence was exactly a liveness probe. It recorded that the
script exits 0 on a tree with no `.jeffy/metrics/` and says so in one line,
which establishes one branch of four and nothing at all about any figure the
script derives. Every number it prints - the per-run iteration count, the strike
sum, the minute conversion, the run and iteration totals, the gate-reached
total - was unverified.

Here each is known by construction: this battery writes the record files, so
every answer is arithmetic fixed before the script runs.

## What it drives

- **All four documented branches**, each required to exit 0 rather than fail,
  because this is a reader and not a gate: no metrics directory, a directory
  holding no records, `jq` absent, and a real corpus. The `jq`-absent arm
  symlinks the script's other tools in by name with `jq` deliberately left out,
  because a `PATH` holding one directory also hides coreutils and the script
  would die at 127 before reaching the branch under test - the defect the
  `install-sh` battery recorded. Its guard is derived from the condition, never
  from an exit code.
- **The computed figures over a two-run corpus.** Strikes are spread across all
  three of run A's records, so a sum reading only the last record is caught. The
  gate is reached in two of those records while only one run carries it at all,
  so a per-run count cannot pass as the per-turn-end count the output line
  claims. Zeros are present as values, so a fallback firing on a legitimate zero
  shows up as `-` where `0` belongs.
- **Every documented fallback, alone and together.** A record carrying none of
  the read fields, and then each field absent on its own, so no fallback is
  established only in a group.
- **The one documented parameter at values that must disagree**: two corpora
  whose outputs differ, and the default read from the working directory.
- **The boundaries the arithmetic turns on.** 119 seconds is the discriminating
  input for floor-versus-round; a rounding implementation prints `2m`. 59
  seconds must print `0m` rather than `-`. And a record nested below
  `.jeffy/metrics/` is part of the corpus, which is behaviour a reader would
  otherwise have to infer from the absence of `-maxdepth`.

## Seen to fail

The `claims` file records each mutation and `check-claims.sh` re-executes them:
a strike term dropped from the sum; the iteration total counting runs instead of
records; the minute conversion rounding where it must floor; an absent field
reported as `0` rather than unknown; the gate total counting runs where the
printed line says turn-ends; the record search stopping at the top directory;
and the project-root argument ignored.

That last one is deliberately **not** isolating - it falls sixteen arms, because
ignoring the argument makes every arm read this repository's own metrics instead
of its fixtures. It is kept precisely for that: it establishes that nearly every
arm depends on the parameter being honoured, which is what driving a parameter
is supposed to show.

## One mutation that passed, and why

The first form of the strike mutation piped the record file into `jq` while
leaving `"$f"` as `jq`'s file argument. `jq` reads the file and ignores stdin,
so the sum was still over every record: the staged file differed from the
original and the program behaved identically, and the battery passed 24/24.

That is the Lesson this run promoted one iteration earlier, met immediately
afterwards by the run that wrote it - a mutation differing from the original
file has not thereby changed what a check derives. The fix was to print the
derived figure either side of the mutation before reading any verdict: shipped
`4`, mutated `2`. The mutation kept in `claims` drops one term from the
summation instead, which is both quote-free (so the claim stays a single line)
and confirmed to move the same figure.

## The expected total

`run.sh` records 31 executed checks, while `grep -c '^ *ck "' run.sh` returns
34. The difference is not a dropped check: the `jq`-absent branch writes its
three checks once per arm, so three of the 34 sites can never run in the same
pass. The executed figure is worked out from the arms beforehand, and a
disagreement with it gets explained before it gets edited.

It read 24 against 27 until run 27 iteration 2. 1.28.0 gave this reader two
new columns, `IN_M` and `OUT_K`, and two new parameters behind them,
`--weights` and `--input-price`, and left four of this battery's arms pinning
the header and the three row shapes without them - so the instrument was red
for a release while the columns it existed to grade had no arm at all. The
seven arms added there are the token section, and their answers were worked
out before the run and not read off it: the fixture's per-session-last sums
are 1,500,000 on the input side and 30,000 out, giving `IN_M` 1.5 and `OUT_K`
30; flat weights total 1,530,000 with the cache read 61 percent of it and
`1,2,3,4,6` total 4,580,000 with the read 82 percent; and at 4 USD per
million those two totals cost 6.12 and 18.32. One of the seven was wrong on
its first run and the way it was wrong is worth the line: `COST` is the
twelfth field of the squeezed row and the arm read the eleventh, so it
compared the read share against the cost and reported `61 82` where it wanted
`6.12 18.32` - a field index is part of the expectation and it was fixed by
reading the real header rather than by taking what the run returned.

## What it cannot reach

- The script reads records the Stop hook writes, and nothing here asserts that
  the hook writes the fields these names refer to. The fixtures define the
  schema this battery believes in; `.jeffy/probes/stop-hook` owns the writer.
- The `jq`-absent arm skips rather than failing on a host where the other tools
  cannot be symlinked, and says so in that case.
- Output formatting is compared as a field sequence with runs of spaces
  squeezed, so the column widths are not pinned - deliberately, since the
  figures are the claim and the widths are presentation.
- This is maintainer tooling outside the shipped runtime: neither installer
  copies `scripts/`, so a finding here is priced as such.
