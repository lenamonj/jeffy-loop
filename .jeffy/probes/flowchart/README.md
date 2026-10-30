# flowchart

Known-answer battery for `scripts/render-flowchart.py`, the third media render
script that no check and no battery read.

The script renders `media/flowchart.mmd` with mermaid-cli and then rewrites the
result in the browser: `REROUTE_JS` replaces five edges dagre draws badly, and
`RESAMPLE_JS` hangs an invisible companion polyline off every long edge so
chevrons trace the true curve at even intervals. Both halves address the live
mermaid DOM by id, and both degrade silently when that DOM moves. A route whose
edge id no longer resolves is pushed onto a list the script only prints; a
marker id that no longer resolves leaves every chevron referencing nothing and
drawing nothing. The published PNGs come out looking plausible either way,
which is why the previous sweeps could not tell a working render from a
degraded one.

The battery imports the shipped module and drives its own `REROUTE_JS`,
`RESAMPLE_JS`, `MARKER`, `AMBER_MARKER`, `SPACING` and `THEMES`, so it grades
the code that ships rather than a transcription of it.

What it asserts:

- Both marker ids the script hardcodes resolve in the SVG mermaid really
  produces, with an id the script never names as the negative control.
- Every node `media/flowchart.mmd` declares resolves in the SVG through the
  very selector `REROUTE_JS` addresses nodes by, so a render that drops a node
  or a mermaid release that changes the id scheme is caught rather than
  producing a chart that is merely missing something.
- All five manual routes resolve, none reporting `MISSING`.
- The amber edges in the SVG are exactly the dotted state-plane edges the
  `.->` declarations in `media/flowchart.mmd` name. `linkStyle` addresses those
  edges by declaration index and the comment beside it warns that an edge added
  earlier shifts them; comparing how many edges came out amber cannot see that,
  because a shift moves the colour without changing how much of it there is.
  Comparing which edges can, and nothing checked it before.
- `SPACING`, the one documented parameter, at three values that must change the
  chevron count: the shipped value, half of it, and a value longer than every
  edge, which drives from the outside the zero-chevron case the script aborts
  on.
- Both `THEMES` entries render, and the two SVGs must differ.

## Discriminating inputs

Recorded at creation. Each was applied to the shipped file, run, and restored
with `git show HEAD:<path>`.

- `scripts/render-flowchart.py`, `MARKER` repointed from the `my-svg` prefix
  mermaid-cli emits to a `mermaid` one: both themes fault on the missing marker
  id, which is the silent mermaid-DOM drift this battery exists for.
- `scripts/render-flowchart.py`, the `L_PROM_BUDGET_0` route renamed to an edge
  dagre does not emit: both themes fault reporting `L_PROM_NOWHERE_0:MISSING`.
- `media/flowchart.mmd`, `linkStyle 33,34,35,36` shifted to `32,33,34,35`: both
  themes fault naming the edge the shift coloured instead, `L_RECORD_REPORT_0`
  in place of `L_REVERT_GIT_0`. This is the mutation that proves the identity
  comparison earns its keep - the first version of the check compared counts
  and passed this unchanged.
- `media/flowchart.mmd`, the same directive narrowed to three indices: the
  battery refuses to run rather than comparing, because the source then states
  no contract for it to check - four dotted edges declared against three
  coloured.
- `scripts/render-flowchart.py`, `SPACING` raised past every edge length: both
  themes fault on the zero-chevron case, which is the `SystemExit` branch the
  script carries for an SVG whose shape has changed.

The node-set check is the only one here with no discriminating mutation of
the source, and saying so is the point of this list. Its negative control works
- a name the source never declares is reported missing, so the lookup is not
vacuous - but three attempts to move it from the mmd side all failed and are
recorded here so a later run does not spend the attempts again. Renaming a
node's declaration alone leaves the edges referencing the old id and mermaid
creates it implicitly, so both names resolve. Declaring a node no edge
references renders it anyway. Renaming a node throughout, declaration and edges
together, is caught by the route check rather than this one. What this
check is therefore evidence of is bounded to a render that drops a declared
node or a mermaid release that changes the id scheme, neither of which this
tree can provoke, and it is kept for that class rather than credited with
more.

Two of these are carried in `claims` as executable mutate-run-restore lines.

## Running it

    bash .jeffy/probes/flowchart/run.sh [tree-root]

Exit 0 and one summary line when every known answer holds, 1 with the
disagreements, 2 when the host supplies no Playwright or no working node.
`run.sh` resolves node by execution rather than by lookup, because an nvm
upgrade leaves `/usr/local/bin/node` a dangling symlink that `command -v`
happily reports and `exec` then refuses.
