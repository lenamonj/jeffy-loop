# packaging

Known-answer battery for the Python packaging surface: `pyproject.toml` and
`hatch_build.py`. The wheel is what a user installs from PyPI, and the build
hook rewrites the README that becomes that release's long description - the
text a user reads on the project page before deciding to install. PLAN.md's
Oracle class line calls `hatch_build.py`'s zero the sharpest in its coverage
listing, because it is a build backend hook the wheel runs and no check in the
harness reads it. This battery is the instrument that zero was missing.

`hatchling` is not installed on this host. Only its base class is stubbed, and
the stub supplies nothing but the two attributes the real base class would -
`self.root` and `self.config` - so `ReadmeHook.update` is the shipped code
running over the shipped regexes and the real file read, not a transcription of
them.

Two roots. The files under test resolve from `JEFFY_PROBE_ROOT`, so a staged
mutation needs only `hatch_build.py` and `pyproject.toml` beside it; the real
README and the tracked-path listing always come from the project root, because
the invariant worth asserting is about the README this repository publishes.

## What it drives

The manifest half is checked against the tree rather than read. Every path the
wheel's `force-include` map names, every path in the sdist's `only-include`
list, and the wheel `packages` path are each resolved on disk, and the count
the extractor produced is asserted beside the misses - an extractor that read
nothing reports zero missing, which is the shape of a check that looked at
nothing. The sdist is separately required to carry the two files the build
itself reads, `README.md` and `hatch_build.py`, since a release that cannot be
rebuilt from its own sdist is not reproducible. The console-script entry point
is resolved to a real callable rather than string-matched.

The rewrite half is known-answer, one shape per reference carrier, with the
expected string written out rather than computed from the same regex under
test: a relative `src`, a relative `srcset`, a relative markdown link, a
relative markdown image, and the five forms that must be left alone - `http`,
`https` in both carriers, a bare anchor, and a `mailto:`.

The `repo` config value is the hook's one documented parameter and it is driven
at two values that must disagree, in both rewrites, so a hook that ignored its
configuration could not pass by matching one of them.

Last and most importantly, the invariant the hook exists to establish is
asserted over the real README: no relative `src`, `srcset` or markdown link
survives into the published text, and every reference the hook did rewrite
names a path `git ls-files` reports as tracked - so a published page cannot
link into nothing. Both the rewritten-`src` and rewritten-link populations are
counted as well as checked, because zero rewritten references would make the
missing list empty for the wrong reason.

## What it was observed failing on

Recorded at creation. Each mutation is replayed by a line in `claims`, each was
confirmed to compile and to differ from the shipped file first, and each is
applied with `awk index()` rather than a regex, because the shipped lines carry
`?`, `|`, `(`, `[` and `$` and an escaping that has to survive being copied
into a state file is an escaping that will be lost.

- Deleting the `src`/`srcset` rewrite leaves all eight of this README's media
  references relative in the published text, which the invariant arm reports by
  listing them.
- Deleting the markdown-link rewrite leaves all of this README's relative links
  relative, and drops the rewritten-link count to zero.
- Replacing the `self.config["repo"]` read with a literal changes every
  rewritten URL, and the two-slug arms fall because one value no longer
  reaches the output.
- Removing `#` from the link lookahead rewrites a bare anchor into a repository
  URL, so in-page navigation on the project page breaks.
- Removing one `force-include` pair from `pyproject.toml` drops the pair count,
  which is the shape of a wheel shipping one skill instead of two.

## The four carriers, and what closed them

Four arms used to assert behaviour that was wrong, under labels beginning
`known gap:`. They were there because a battery that simply omitted these
shapes would read as coverage, and the gap sat on the ledger as a class
finding rather than hidden here. J10 closed it and these arms were rewritten
in the same iteration, which is the coupling they promised; they now assert a
refusal naming the reference that would have shipped, under labels beginning
`refuses:`. The four carriers the two rewrites cannot read:

- `srcset="a.png 1x, b.png 2x"` has only its first candidate rewritten,
  because the rewrite prefixes the attribute value whole.
- `<a href="docs/usage.md">` is not touched at all.
- `[u](docs/usage.md "Usage")` is not touched, because `[^)\s]+` cannot span
  the space before the title.
- `src="//cdn.example/x.png"` is protocol-relative and already absolute, but
  the lookahead excludes only `http://` and `https://`, so the raw prefix is
  glued on and the result resolves nowhere.

None was live in the README when the class was filed and each was confirmed
absent by its own count, which is why it was filed as a class rather than as a
reproduced present defect. The fix verifies the hook's own output rather than adding a regex per
carrier: the hook verifies its own output through extractors deliberately
wider than its rewrites and fails the build on anything that would resolve
nowhere, so a fifth carrier nobody anticipated fails loudly too. The other
side of it is asserted here as well - the README this repository actually
publishes must pass that same assertion, or the fix would have traded four
broken references for a build that cannot run.

Two of this battery's own mutations moved with that fix and were re-pointed in
the same iteration rather than left mismatching. Dropping either rewrite used
to be detected by this battery's own survivor arms; the hook now refuses first,
so the detection is the refusal naming the carrier, which is the stronger
signal of the two. One of them also had to be narrowed: its pattern matched
`mailto:`, which the fix made appear on a second line, so it deleted both and
raised a NameError that read exactly like a battery discriminating nothing.

## What it cannot reach

The wheel is never actually built here, so nothing asserts that `hatchling`
honours the manifest this battery reads, that the hook's output lands in the
built metadata, or that the hook scripts keep their executable mode through
the wheel. Those need `hatchling` installed and a real build. The
`requires-python` floor is read as a declaration and not tested: this host
carries one interpreter, so no arm can show the module importing on the oldest
version it claims.
