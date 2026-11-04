# repo-meta battery

Known-answer battery for the repository metadata group - `SECURITY.md`,
`CONTRIBUTING.md`, `LICENSE`, `.github`, `.gitattributes` and `.gitignore`.

## Why this surface earns an instrument

`.github` is one of the zeroes the Oracle class line in PLAN.md names. Run its
own coverage command - `git ls-files | sed 's|/.*||' | sort -u` piped through
`grep -cF` over `scripts/validate.sh` - and `.github` returns 0, so no check in
the harness reads either workflow or any issue template. That is the sharpest
zero in this group, because `.github` holds the only two things here that
execute:

- `validate.yml`, whose job matrix is the oracle behind a sentence three
  published pages state - that the engine passes its checks on Linux, Windows
  and macOS. Nothing read that matrix until now. Drop the macOS job and three
  published sentences become false with nothing going red anywhere.
- `publish.yml`, which builds and uploads the wheel a user installs from PyPI.
  It carries a shell guard of its own, refusing a release whose tag does not
  name the version in `pyproject.toml`, and that guard is published code under
  this project's Publication rule.

## What it drives

- **The `.github` file set**, read off the directory and asserted whole, so a
  workflow or template added or removed reaches this battery rather than
  passing unnoticed.
- **Every YAML under `.github` parses.** A malformed workflow does not fail
  loudly - GitHub declines to run it - and a malformed issue template is
  silently dropped from the chooser, so both failures look like nothing
  happening.
- **The CI matrix is the one the published pages claim.** The runner set is
  derived from `validate.yml` and compared against the pages that state the
  trio, with those pages enumerated by command rather than typed and held to a
  floor, so a page that drops the sentence cannot shrink the set into
  agreement. Each surviving page is then required to name all three, so a page
  narrowed to two is a disagreement rather than a smaller set.
- **Every action is pinned to a commit, not a tag.** A floating tag is a third
  party's mutable pointer running in a workflow that holds `id-token: write`.
  The population is counted beside the predicate, and each pin is required to
  carry its version as a trailing comment, which is this repository's own
  convention and the only thing that makes the SHAs readable.
- **A release cannot publish without the validator.** The upload job's
  dependency on the validating job, that job really running the suite, and the
  trigger being a published release alone - all read out of the parsed
  workflow, which is also where `on:` has to be fetched under the YAML 1.1
  truthy key rather than the string.
- **The tag-versus-version guard runs as published.** It is extracted from the
  workflow and executed in exactly the form the workflow carries, under
  `bash -e` because that is what GitHub gives a `run:` block, and driven on
  both sides of its own comparison: the real version accepted, another version
  refused.
- **Least privilege** on both workflows, and the upload job holding the
  trusted-publishing token that only it needs.
- **`.gitattributes` covers what the tree actually holds.** The binary pins are
  not decoration: a tracked `.png` git treats as text is eol-converted on a
  Windows checkout and the file is corrupt. The pinned set is compared against
  the extensions the tree really tracks, so a new binary kind committed without
  a pin is a finding rather than a silent risk. The three LF pins the file
  explains in its own comments are asserted individually, each load-bearing for
  a mechanism named there - byte-exact templates, check 10's anchored patterns,
  and `git apply` over the published receipt patches.
- **`CONTRIBUTING.md`'s published commands parse**, a contributor copying them
  being the reason, with the non-empty guard ahead of each because an extractor
  returning nothing hands `bash -n` an empty script that parses clean.
- **The licence the package declares is the one the file grants.**

The expected total is written at the head of `run.sh`, worked out from the arms
before the run and never read off a green one.

## Deliberately not re-asserted

The truncator set and the sandbox answer set `SECURITY.md` states are already
derived by checks L and Q, and the three transient paths `.gitignore` must carry
are asserted by the harness beside its exploratory-output check. Restating any
of them here would give a single claim two sources rather than adding coverage,
which is the defect PLAN.md's comparison-discipline paragraph exists to prevent.

## Seen to fail

The `claims` file records each mutation and `check-claims.sh` re-executes them,
so the discriminating power is re-derivable rather than asserted here. Every one
was staged on a faithful copy and confirmed to differ before its result counted.
What they move: the macOS runner retargeted at ubuntu; a published page narrowed
to two runners; an action pin replaced by a floating tag; the upload job's
dependency on the validator removed; the tag guard's comparison inverted; the
`png` binary pin removed; top-level permissions widened to write; the `*.patch`
LF pin removed; and an issue template made invalid YAML.

Two of them move more than one arm, and that is recorded rather than tidied
away. Inverting the tag guard flips both sides of it, which is the point - a
guard that accepts everything and one that refuses everything are both broken.
Deleting the macOS job outright, which was the first form of the runner
mutation, also removes that job's checkout step and so falls the action
population too; the mutation kept in `claims` retargets the runner instead,
which isolates to the runner set alone and is the better instrument for it.

## What it cannot reach

- Nothing here runs a workflow. What is established is the workflow's declared
  shape and the one shell guard it carries, never that GitHub schedules it, that
  the runner images hold what the steps assume, or that trusted publishing is
  configured on the PyPI side.
- The pinned action SHAs are checked for being commit-shaped, not for naming the
  commit the trailing version comment claims. Resolving that needs the network.
- `uv build` is not run, so nothing here asserts the wheel the publish job
  uploads matches the manifest; `.jeffy/probes/packaging` owns that, and it does
  not build a wheel either.
- The issue templates are parsed, not validated against GitHub's form schema.
- `SECURITY.md`'s and `CONTRIBUTING.md`'s prose is not graded beyond the arms
  above and the harness checks named under *Deliberately not re-asserted*.
