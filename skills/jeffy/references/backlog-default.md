# Backlog

Ledger, not narrative. Top unblocked item is next. Markers: [ ] open, [b] blocked.

Rules:
- One line per item: `- [ ] <ID> (<Severity>, <class>, <dimension>): <finding>. Acceptance: <runnable command or observable fact>.`
- Class is one of runtime, test, build-ci, docs, dev-tooling, chosen by the files the fix will touch; a line without one is read as runtime. Within a section, order by severity first, then runtime before the other classes.
- A finished task is deleted from its section and recorded as one line in the JOURNAL entry that closed it. No done markers accumulate here.
- Run context, audit scores, and DONE annotations live in JOURNAL.md only. No prose sections and no headings beyond the ones below, ever.

## Now

## Next

## Later

## Proposed

Items needing a user decision before any work, one plain line each, never a checkbox task: envelope changes, audit escalations, challenges to a settled class. Never worked without explicit user approval and never counted against convergence.

## Settled classes

One line per class: the idiom or defect class, the surface it applies to, and how it was settled - fixed class-complete with its enumerating check, or declined with the reason. Audits must not file findings inside a settled class unless its implementing code changed after settlement.

## Declined

Findings judged not worth fixing, one line each with the reason. Audits must not re-file these.

## Converged

One line per convergence, appended, never rewritten: Converged: <full commit hash> - <date>. The ratchet reads the latest line here, and that hash has to stay reachable from HEAD: a commit no clone can reach certifies nothing anyone else is able to check.

A history rewrite that preserves the tree - a squash, a rebase, a filtered export - is answered by appending, never by editing the line it orphaned: `Converged: <new hash> - <date> (repoints <old hash>, tree unchanged)`. That is legal only when `git rev-parse <old>^{tree}` equals `git rev-parse <new>^{tree}`, and the superseded line stays exactly where it is, because it is the only record left in the tree that the rewrite happened at all. The same iteration appends a dated `## Note` to JOURNAL.md naming both hashes and what was rewritten. A repoint across two different trees is a new convergence claim wearing an old certificate, and it is refused.
