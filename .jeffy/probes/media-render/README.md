# media-render

Known-answer battery for `scripts/render-running-jeffy.py` and
`scripts/render-how-it-works.py`, the two media render scripts that belonged to
a Surface inventory row nothing could evidence. `py_compile` plus "the
committed GIF and PNG exist" was all a sweep could previously obtain, and
neither is a correctness check on a computed value, so the row sat unswept
across two runs.

What it grades is the arithmetic the two pages perform, driven through a real
Chromium at the viewports the scripts hardcode. The expected values are
recomputed in Python from the constants `media/how-it-works.html` declares -
`TOTAL`, the typing window, the three iteration frames, the `STAGES` table and
the badge fade window - rather than recorded from a run, so the battery
disagrees with the page whenever either side moves. The comparison is numeric
rather than string-exact on purpose: the browser re-serializes an inline style
value and drops trailing zeros, so comparing `toFixed` output would grade CSS
serialization instead of the animation.

Documented parameters, each at two or more values that must change the output,
with boundary and negative sides:

- `theme`, at its default, at `light`, and at a value that is neither, which
  must fall back to the default render.
- the frame index `setFrame(n)` sweeps, at every `STAGES` boundary and the
  frame before it, at both ends of the typing ramp, at both ends of each of the
  three glyph turns, and at both ends of the badge fade.

It also drives the correctness claim the script's own docstring makes - that
`setFrame(n)` fully determines the image - by screenshotting frame 0, then 239,
then 0 again, and requiring the two frame-0 images to be byte-identical and the
frame-239 image to differ.

## Discriminating inputs

Recorded at creation, because an instrument never seen to fail reads exactly
like one that passed. Each was applied to the shipped file, observed to change
what the page computes, run, and then restored with `git show HEAD:<path>`.

- `media/how-it-works.html`, camera coefficient `0.03` to `0.031`: the camera
  comparison faults from frame 16 onward, which is the first frame where the
  fourth decimal the page prints separates the two.
- `media/how-it-works.html`, `TOTAL=240` to `241`: the `TOTAL` known answer
  faults, and the camera ramp faults with it because every frame now sits at a
  different fraction of the sweep.
- `media/how-it-works.html`, `setFrame(n)` opening with `n=0`: the typed
  command and the camera fault from frame 4, and the frame-sensitivity
  screenshot check reports that frame 239 renders identically to frame 0.
- `media/running-jeffy.html`, the one-line `theme=light` switch deleted: the
  `data-theme` attribute, the computed background and the byte comparison
  between the two theme renders all fault together.
- `media/running-jeffy.html`, declared height `760px` to `780px`: the declared
  page size faults under all three theme values, which is the shape a page that
  has outgrown the viewport its script hardcodes takes.

Two of these are carried in `claims` as executable mutate-run-restore lines so
`skills/jeffy/hooks/lib/check-claims.sh` re-establishes them rather than
trusting this list.

## Running it

    bash .jeffy/probes/media-render/run.sh [tree-root]

Exit 0 and one summary line when every known answer holds, 1 with the
disagreements, 2 when no Python carrying Playwright can be resolved - which is
an instrument finding about the host rather than a product defect. `run.sh`
prefers a Python that already imports Playwright and falls back to
`uv run --no-project --with playwright`; `battery.py` tries Playwright's own registered
browser first and globs the Chromium cache only when that build is absent,
which is the state a host is in whenever the Python package has been upgraded
without re-running `playwright install`.
