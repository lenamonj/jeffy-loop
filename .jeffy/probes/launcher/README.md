# launcher battery

Known-answer battery for the `/jeffy` launcher skill (`skills/jeffy/SKILL.md`).

## Why this surface earns an instrument

The skill is prose an agent executes, so most of it has no mechanical oracle and
this battery does not pretend otherwise. One part of it does have one, and it is
the part this repository's own Lessons record as having broken twice.

The launcher writes the loop state file; the Stop hook reads it. The two share a
key contract, and nothing checked it. The Lesson reads: *"A mechanism this
engine ships and its own repository does not use is untested where it matters
most. When a release adds a state-file line the hook reads, this project's own
state files record it in that same release, or the next run rediscovers the gap
by being refused."* It is marked `[recurred]`, and its recorded second instance
is `Verify summary pattern`, which the wrapper began reading and nothing
declared - so the wrapper fell back to a shorter line and the run read as
healthy. That is the failure mode: a key the hook reads and nobody writes does
not fail loudly. The reader returns empty and the feature silently takes its
default.

## What it drives

- **The pre-flight steps are a contiguous run from 1.** The steps are
  cross-referenced by number from the skill's own later text and from PLAN.md's
  inventory rows, so the numbering is a machine-read value rather than styling,
  and a duplicated or skipped number is a step a launch reads past.
- **The state-key contract**, as three sets each derived from the file that owns
  it: the hook's `fm <key>` readers, the hook's own `"<key>: ` emissions, and
  the keys in the launcher's heredoc including the three conditional lines whose
  key sits inside an angle-bracket placeholder. The contract asserted over them
  is that nothing the hook reads is unwritten by both sides.
- **The other direction, named rather than tolerated.** The launcher writes one
  key nothing reads - `sandboxed`, the blast-radius disclosure for a human
  reading the state file, which BACKLOG.md states in F1's own reasoning. That
  set is asserted to be exactly that key, so a second orphan is a finding
  instead of slack, and the hook is separately confirmed never to mention it.
- **The state file round-trips through the hook's own reader.** The reader is
  extracted out of the hook rather than retyped, because a second copy of a
  parser is the defect the Lesson about calling rather than re-typing a shared
  predicate already records. A state file is built in the launcher's documented
  shape and every key read back through that extracted reader.
- **The templates the launcher copies are the shipped set**, compared both ways,
  so a template named but absent (which breaks a launch on a fresh project) and
  one shipped but never named (which is never copied) both fault.
- **The promise phrases** the launcher writes into `completion_promise` are the
  ones their prompts instruct the model to emit; a disagreement makes a correct
  declaration unrecognisable to the hook.
- **The flag set, the two `--refeed` values, and both mode words** the guard
  compares.
- **Every path under `hooks/` the skill names exists.** check 3 asserts a
  hand-written list of required paths; what is derived here is the set the skill
  itself names, so a library added to the launch sequence cannot be missed by a
  list nobody updated.

## Deliberately not re-asserted

The fenced bash blocks, which check 10 parses. The verify-bound derivation
chain, which check P rebuilds and compares against three documents. The
truncator set and the sandbox answer set, which checks L and Q derive. The flag
set against `docs/usage.md`, which `.jeffy/probes/docs` compares. Restating any
of them would give a single claim two sources rather than adding coverage.

## Seen to fail

The `claims` file records each mutation and `check-claims.sh` re-executes them.
What they move: the hook given a reader for a key nobody writes; the launcher
stripped of a key the hook reads; a second launcher-written key nothing reads; a
duplicated pre-flight number; a template renamed in the bootstrap block; a flag
renamed throughout; a hook library renamed; and the hook's frontmatter reader
stripped of its colon anchor, which drops every key out of the round trip at
once.

## Two inadequate mutations, and how they were caught

Both are recorded because each read, at first glance, like the battery failing
to discriminate - and neither was.

The first was a mutation that did not land at all. Replacing the hook's
`sed -n "s/^$1: //p"` through a shell `awk -v` assignment lost its quoting in
transit, exactly as the Lesson about escaping lost in transit predicts; the
staged file came back byte-identical and the guard comparing it against the
original said so. That is why `mutate.py` exists here: it takes the literal
strings as argv, replaces them, and exits non-zero when the target was never
present, so a mutation that silently failed cannot be read as a pass.

The second landed in the file and still changed nothing the battery reads.
Deleting one mention of `--max-context` from the Arguments section left the
derived flag set identical, because the extraction is a `sort -u` over every
site and that flag is named twice there. The file differed, so a diff-based
guard was satisfied while the program under test behaved identically - which is
the Lesson about proving a mutation changed behaviour before its result counts,
met from its subtler side. The kept mutation renames the flag throughout, and
the derived set was confirmed to have moved before the verdict was read.

## The expected total, and why it was not simply edited

`run.sh` records 19, which is what `grep -c '^ *ck "' run.sh` returns, with no
`ck()` inside a loop. It was first written as 20 and the run reported 19 - the
shape the Lesson about a silently dropped check warns of. The static call sites
were counted before the number was touched; they agreed with the run at 19, so
the error was in the planning arithmetic rather than in the battery. A count
that disagrees gets explained before it gets edited.

## What it cannot reach

- Nothing here executes the skill. It is instructions for an agent, so what is
  established is the internal consistency of its machine-read values and their
  agreement with the hook - never that a launch follows them. The run's own
  launch is the only evidence of that, and it is evidence about one launch.
- The pre-flight checks are not driven. Their numbering is asserted; what each
  one does is not.
- The hook-written key set is derived from emission sites, so a key the hook
  writes through a variable rather than a literal prefix would be missed. The
  partition would then report that key as read-but-unwritten, which fails loudly
  rather than silently - the safe direction.
- `sandboxed` is asserted to be the only orphan key, not to be *correct*. The
  detector that produces its value is covered by `.jeffy/probes/detect-sandbox`.
