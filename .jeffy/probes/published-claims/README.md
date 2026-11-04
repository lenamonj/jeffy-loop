# published-claims

README.md and evals/README.md are the two pages a reader judges this project
by, and between them they state the whole of its evidence. Check J already
derives every `count:` marker on every published page from the receipts table,
so none of those totals is restated here - restating any would hand a single
assertion a second source rather than add coverage.

What check J cannot see is prose. Run `grep -cF` over scripts/validate.sh for
`blocked at the close`, `all but five`, `Convergence standard` and
`countersigned` and all four return 0, so the two sentences that quantify over
the receipts themselves had no oracle at all. One of them is new in the release
this run's focus diff covers, and PLAN.md's own rule is that a published number
joins the Derived list in the commit that introduces it. This battery is what
it joins.

Nor does anything open the links: `grep -cF 'details](./' scripts/validate.sh`
returns 0, so the harness matches the receipts table's row shape and never
resolves the target it points at.

## The sentences are rendered, never parsed

Both published sentences are built from the derived figures and required
verbatim. That is this project's Lesson about comparing a canonical form rather
than classifying prose, and rendering is the stronger direction: a locator
accepts whatever wording its own pattern happens to read, where rendering
requires the page to carry exactly what the receipts say. A cardinal with no
word in the rendering table faults rather than rendering digits the page could
never carry - the shape in which a derived value silently stops being
comparable.

## What it establishes

**The standards split.** Every converged receipt states one `Convergence
standard`. The classes are enumerated rather than whitelisted, so a value
outside them faults instead of being dropped - a member the extractor drops is
a claim nobody compared. The classes are required to account for every receipt
that states one, and that total is required to equal the front page's own
converged marker, because the split is a partition of exactly that set and
means nothing if the two disagree. Then the front page is required to carry the
split sentence the receipts render, once.

**The blocked-at-the-close count.** Derived from the rows that carry the
annotation, never from either sentence, and required on both pages in each
page's own wording. Two further properties make the count the claim's own
subject: every annotated row must be a Fixed row, since the sentence is about
converged work, and every annotated row must have a receipt on disk.

**The links.** Every details link resolves, every receipt on disk is linked by
a row, and every other relative reference on both pages resolves - each target
checked against the page it was found on, because a relative path resolves from
its own directory. Scheme-bearing and anchor-only targets are excluded by
shape. Populations are counted beside every miss list, because nought
references examined empties that list for the wrong reason.

**The front page's anchors.** Each one names a heading on the page. The slug
rule is proved on a heading that exists and on one that does not before its
silence counts, since a rule matching everything reads exactly like a page with
no dead anchors.

## Seen to fail

The claims file records one mutation per arm so the discriminating power is
re-executable rather than asserted: a receipt standard outside the three
classes, a receipt moved between classes, the split restated in digits, a
dropped row annotation, an annotated row whose result cell leaves the claim's
subject, a dead details link, a dead relative reference, a dead anchor, and a
converged marker the split cannot account for.

Two of them are worth naming. The dropped annotation must fall both page arms,
not one, because the whole point of stating a number twice is that either copy
can drift. And moving a receipt between standard classes leaves the converged
total alone, so it falls only the rendered-split arm - which is what makes that
arm, rather than the partition arm, the place where the published sentence is compared.

## What it cannot reach

The stage copies the whole of evals/ and the directories the front page points
into, because the arms walk every receipt and resolve every reference; a
partial stage would report misses no mutation caused, which is the defect the
docs battery recorded on its own first mutation run. The baseline is re-run on
the stage before any mutation verdict is read.

Nothing here reads a receipt's body for truth. A receipt's oracle is its own
target's clone and run record, which PLAN.md settles, so what is established is
that the pages agree with the receipts as a set - never that a receipt is
right.

The anchor arm covers the front page alone, because the receipts page carries
none; a link from one page into another page's heading is resolved as a path
and its fragment is dropped, so a fragment that names no heading on the target
page is outside every arm here.
