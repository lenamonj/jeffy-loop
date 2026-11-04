# probes-meta

A battery declares a `paths` file the engine reads to derive a row's staleness
and a `claims` file the gate executes. Both of those are load-bearing, and both
fail quietly: a battery no row names is never run by a sweep, and a row naming
a battery that does not exist is a row the closing gate cannot derive at all.
Nothing was reading either direction.

## The two directions

The batteries no inventory row names are asserted as a set, because that set is
the probes row's own subject - three of them, each one a declared gate that no
sweep reaches. And the reverse: every battery a row names must exist, since the
Stop hook derives a battery-bearing row's staleness from that battery's own
paths file and a name it cannot resolve leaves the row underivable rather than
stale.

## The third row classifier

This is the arm that found something. PLAN.md carries two commands that
classify inventory rows: one reads a row against the commit it was swept at,
and one reads the tree against the rows to find surface no row claims. Between
them they look in both directions and neither reads a row against the tree, so
a row claiming a path that no longer exists is invisible to both. One was:
the renderer row carried `scripts/render-banner.py`, retired when the flat
banner files were, and both commands had stayed quiet for every run since.

The arm is here and the command is also in PLAN.md's own Surface inventory
section, because a reader of that section should not have to find it in a
battery, and because the Lesson about a row state being read by more than one
instrument is marked `[recurred]` for exactly this shape.

## What else it establishes

Every battery carries a non-empty `paths` file and a `run.sh` that parses.
Every path a battery declares exists, and none of them is the directory the
engine writes a telemetry record into at every turn end - a scope covering that
is stale immediately after every checkpoint, no re-sweep can clear it, and the
map becomes permanently unclearable, which is a Lesson this project learned on
its own inventory.

Every `claims` file holds only `expect` lines or the single word `none`, which
is the shape `check-claims` reads and the only shape it reads. The batteries
carrying no claims file at all, and none carrying no README, are named under
`known gap:` labels rather than passed over: a battery with no claims file is
an instrument whose discriminating power nothing can re-execute, and an arm
that omitted them would read as coverage. Filed as J14, not hidden here, and a
fix turns those two arms red in the same iteration deliberately.

Directory names are held to the character set the enumerating command reads,
because that command is how the probes row is derived and a name outside the
set would silently drop a battery out of it.

## Seen to fail

The claims file records one mutation per arm: a declared path pointed at
nothing, a declared path pointed at the engine-owned telemetry directory, a
malformed claims line, a claims file removed outright, a battery copied so no
row names it, a row's battery reference renamed, a row's own path renamed, and
a run.sh made unparseable.

The row-path mutation is the one worth naming, because it is the arm that
closed the gap: it renames the path a row claims and the arm reports it, where
both of PLAN.md's existing commands stay silent.

## What it cannot reach

Nothing here runs a battery. What is established is that each one is reachable,
declared, parseable and graded - never that its arms are right, which is each
battery's own business and the reason each carries its own claims.

The stage is the whole tracked tree, because two arms resolve declared paths
and row paths against it, so every tracked file is part of the surface they
walk. PLAN.md is copied into the stage rather than taken from the index,
because it is gitignored in this repository.
