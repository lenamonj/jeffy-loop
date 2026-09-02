# Jeffy eval: rubyzip/rubyzip

The 1,427-star Ruby zip library, the archive layer under Rails' Active
Storage exports, Chef, Fastlane and most Ruby tooling that reads or writes
`.zip`. Run 2026-09-02 as wave 12 (COHORT-WAVE11.md). **5 runs, 46
iterations, converged** in round 5 at
`8da69cbc9576253a6288ec1fcf21e611a2258c0f`, the last round of a
**pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `a31f40ca38fb129bb51adf7e3b0cdb2b73a57781` (master, at v3.6.0) |
| Findings closed | **28** - 10 High, 9 Medium, 1 re-scored to Medium, 8 Low |
| Shipped-code change | 30 files, **+1,347 / -85** (17 under `lib/`, 9 under `test/`) |
| Surface inventory | **17 of 17 rows swept** |
| Ledger at convergence | empty, nothing carried |
| Evaluator | **6 invocations: REJECT, REJECT, REJECT, REJECT, PASS, PASS** |
| Suite at convergence | `bundle exec rake`: `453 runs, 3048 assertions, 0 failures, 0 errors, 2 skips` (417 runs, 2859 assertions at base) |

## What the loop found

The ten Highs, in the order they closed:

- **`RZ-001`** - `Zip::NullInputStream` was a bare module with no instance
  methods, so `Entry#get_input_stream` on a directory or symlink entry
  yielded an object on which `read` raised `NoMethodError`.
- **`RZ-002`** - `ExtraField#merge` read each field's length word from
  the wrong offset, so any archive carrying two or more extra fields in
  one entry mis-parsed every field after the first.
- **`RZ-003`** - `Zip::FileSystem` recognised a directory only when the
  archive stored an explicit entry for it; on archives written without
  directory entries (most of them) the `::File`/`::Dir`-style API omitted
  whole subtrees.
- **`RZ-007`** - every typed extra field packed its instance variables
  back without checking they had been parsed, so a field read from a
  truncated or central-directory-form encoding made any later write of
  that entry raise `TypeError`.
- **`RZ-008`** - rewriting an archive held in a buffer corrupted it.
- **`RZ-012`** - extraction never created a destination's parent
  directories, so an archive with no directory entries failed with
  `Errno::ENOENT` on every nested file and left a partial extraction.
- **`RZ-014`** - extraction's containment check was lexical, so a symlink
  already sitting in the destination directory was a way out of it.
- **`RZ-016`** - an entry whose local header could not be found or parsed
  extracted as a zero-byte file with no error and no warning, against a
  central directory that declared its size.
- **`RZ-019`** - an entry whose central directory record pointed at a
  different entry's local header was read as that other entry: `a.txt`
  came back with `b.txt`'s contents.
- **`RZ-020`** - a failed extraction destroyed the file it was
  overwriting, because the destination was opened `wb` before the payload
  was read. Contents are now written beside the destination and moved into
  place once complete.

The Mediums are mostly the same theme one step down: `sysread` never
advanced `pos` (`RZ-009`); `restore_*` options applied only through
`find_entry` and not through `each`, `entries` or `glob` (`RZ-010`); a
corrupt local header mid-archive read as end-of-stream and silently
dropped every entry after it (`RZ-011`, then `RZ-017` and `RZ-021` to get
the error to actually reach the caller, see below); a central directory
record that ran past the end of the central directory returned an entry
named by whatever bytes followed (`RZ-005`, filed without a severity and
re-scored Medium by the gate, closed at the one boundary where the extent
is known). The Lows include the removal of `Entry#name_safe?`, an
undocumented predicate that after its own `cleanpath.relative?` guard
rejected nothing at all, and answered `true` for `C:/evil.txt`.

Every entry in the project's `Changelog.md` `Unreleased` section is the
loop's, and it reads as a user would need it to.

## What the loop got wrong

**Round 2 ended blocked on two gate REJECTs, and the second was a
regression the loop itself introduced.** Round 2's iteration 5 closed
`RZ-014`, the symlink escape. The gate's first invocation found that the
new containment check swallowed every `SystemCallError` from resolving
the destination, so extracting into a missing or unreadable destination
returned as though it had succeeded, printing a warning that blamed the
entry (`RZ-015`, High). The loop fixed `RZ-015` with three conditions
where, in its own words, "one and a half were needed", and the third
handed the escape straight back: a symlink named `up` inside the
destination, pointing at the destination's parent, wrote `escaped.txt`
beside the destination with no warning - worse than base, where the same
archive wrote nothing only because `RZ-012` had not yet taught extraction
to create intermediate directories. The gate's second invocation caught
it; the loop reproduced it, withdrew the clause, and the round ended
blocked with no declaration. Round 3's gate rejected once more (`RZ-017`'s
guard sat inside a method whose class-method wrapper rescues `Zip::Error`
into nil, so the refusal it added never reached a caller and silenced
three that used to). Round 4 took a REJECT then a PASS, and declined to
declare on that PASS because a fresh full audit was still owed; round 5
ran it, filed one Medium against the previous round's own closing entry
(`RZ-030`), closed it, and converged at iteration 5.

Two of the six invocations rejected on findings the target's own suite
did not cover and the loop's own fixes had caused. That is the gate doing
what it is for. It is also four REJECTs on one target, the most in the
corpus, and the reason this target took the whole budget.

**Loop housekeeping in the product diff.** Iteration 2 of round 1 committed
three extraction artifacts under `tmp/` with a `git add -A` checkpoint;
the gate recorded it (`RZ-027`) and round 5 removed them. The `.gitignore`
gained one line for the loop's own state file. The round-1 journal was
rotated into `JOURNAL-archive.md` in-tree; it is excluded from the
shipped-code numbers above and from `fixes.patch`.

## Upstream

The candidates are `RZ-020` (failed extraction destroys the existing
file), `RZ-019` (wrong entry's contents returned) and `RZ-016` (silent
zero-byte extraction), each a self-contained change with an external
oracle. None has been filed yet; each will be verified on a fresh clone at
upstream HEAD against the project's own `rake` target before it is, per
the standing PR bar.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration of all five rounds
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
