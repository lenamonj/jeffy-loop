# published-docs

The white paper, the STE100 description and the media set are three of the six
paths the Oracle class line's own coverage command reports at zero. Run it and
`grep -cF` over scripts/validate.sh returns 0 for both PDFs and 1 for media,
which is a comment rather than a check. Nothing in the tree reads any of them,
and the two documents are the first thing a reader downloads from the front
page.

## Structure, as an invariant rather than a liveness probe

One number, derived three independent ways: the page tree root's `/Count`, the
`/Type /Page` objects, and the `/Contents` references. A truncated upload, a
half-written regeneration or a corrupt stream breaks the agreement, and no
single one of those derivations would notice on its own. That is what this
file's own rule asks of a row whose surface carries values - a correctness
check, not a run-without-crash probe - and it is why the arm compares the three
rather than printing one.

Beside it: the header and the trailer, one page tree root per document (a
second `/Count` would mean the file is not the single-document shape every
other arm assumes), and a content stream per page at least. The stream arm is a
floor rather than an equality on purpose: an appearance stream is a content
stream too, and a document is free to split a page across several.

## Text without an extractor

PLAN.md's Environment fingerprint records that this host carries neither pypdf
nor pdftotext, and S4 established that the content is reachable anyway. The two
documents need different filters - the white paper is FlateDecode, the STE100
description is ASCII85 then Flate, which is ReportLab's default - so `pdf.py`
tries both and the row does not rest on one generator's habits.

Two details of that reader are load-bearing and both were found by running it.
The decoded set is narrowed to streams carrying a text-showing operator,
because a font or image stream decodes as happily as a content stream and its
bytes are full of parenthesised runs; without the narrowing the extraction grew
by a third in garbage. And the show operators are joined with nothing, because
the generator splits a word across them - inserting any separator invented a
boundary the page does not have, and `References` stopped being findable at
all.

## What the text establishes

The white paper's reference list is read from the last occurrence of its own
heading rather than the first, because the first is the table of contents
entry - and the arm asserts both occurrences exist, so a document whose list
was lost while its contents entry survived faults rather than reading as a
document with a short list. The entries must run contiguously from one with no
gap or repeat, and each must carry a link. The entry marker carries the
generator's own language tag, which is what makes it a marker: a bare `N.` also
matches a sentence ending in a numeral.

The STE100 description must name the standard it is named for.

## The links and the absence

README links both documents by absolute URL, so the sibling battery over
relative references cannot see them; a renamed document would break every
published download link with nothing going red. Every `raw/main/` target is
required to be a tracked file at the repository root.

One arm guards an absence rather than a value. PLAN.md's Derived and settled
numbers section settles the page count and the source count on the ground that
no document states them any more, which is true and decays the moment someone
writes the sentence back. The arm's scope is the claims section's own - tracked
markdown outside `evals/` and outside `.jeffy/` - and that narrowing was driven
rather than chosen: on its first run it hit an evaluator artifact quoting the
old sentence, and an artifact is a frozen record the Stop hook requires
committed and unmodified, so it can never be brought into agreement with a page
that has moved on.

## The media set

Every themed asset ships in both themes. Two conventions are in use and both
are accepted because the set uses both: an explicit `-dark` sibling, or an
unsuffixed default standing in for it.

The media files no tracked file references are named rather than tolerated as
slack - the logo pair is repository chrome and the mp4 is the source the gif
beside it was rendered from, and their consumers are outside this tree. A
fourth orphan is a finding, and the arm is written so it reads as one.

Deliberately not re-asserted: the `.gitattributes` binary pins, which
`.jeffy/probes/repo-meta` derives against every tracked binary extension, and
README's relative media references, which `.jeffy/probes/published-claims`
resolves.

## Seen to fail

The claims file records one mutation per arm. The two that reach the binaries
go through `bmutate.py`, which replaces bytes and refuses a replacement of a
different length, because a PDF's xref table holds byte offsets and a length
change would make the reader fault on the offsets rather than on the value
under test.

The arms over decoded text cannot be driven by a byte mutation, since the text
lives inside compressed streams. They are driven the other way instead, as a
known-answer check on the reader: pointed at the document that has no reference
list, the parse reports no section and no entry, which is what makes its answer
on the white paper mean something.

## What it cannot reach

Nothing here reads either document for whether what it says is true, or for
whether the STE100 description actually conforms to the standard it names -
conformance is a human judgement and the arm asserts only that the document
names it. Nothing renders a page, so a document that parses and extracts
cleanly while laying out wrongly is outside every arm.

The stage is the whole tracked tree, because the orphan arm asks which media
files no tracked file references and every tracked file is therefore part of
the surface it walks; a stage holding only the pages this battery is about
reported eleven orphans on its first run that no mutation had caused.
