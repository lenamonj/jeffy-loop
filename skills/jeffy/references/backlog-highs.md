# Backlog

Ledger, not narrative, and Highs only: the top open High is next. Markers: [ ] open, [b] blocked.

Rules:
- One line per item: `- [ ] <ID> (High, <class>, <dimension>): <finding>. Acceptance: <runnable command or observable fact>.`
- Only a High is filed here. A Medium or Low an audit notices goes on that AUDIT entry's `Noted, not filed:` line in JOURNAL.md and never on this ledger; an open line whose severity is not High is a violation the Stop hook refuses the close on, and so is a line with no parseable severity.
- Class is one of runtime, test, build-ci, docs, dev-tooling, chosen by the files the fix will touch; a line without one is read as runtime. A High of class docs or build-ci carries `Consequence: <what a user of the shipped product meets>` before its Acceptance; a High of class test or dev-tooling cannot exist under the severity ceiling by class. Order by user impact, then runtime before the other classes.
- A finished task is deleted from this file and recorded as one line in the JOURNAL entry that closed it. No done markers accumulate here.
- Run context, audit scores, Noted lines and DONE annotations live in JOURNAL.md only. No prose sections and no headings beyond the ones below, ever.

## Now

## Proposed

Items needing a user decision before any work, one plain line each, never a checkbox task: envelope changes, audit escalations, challenges to a Declined entry. Never worked without explicit user approval and never counted against the close.

## Declined

Highs judged not worth fixing, one line each with the reason and the command or measurement that establishes it, written as `Derivation: <command>` on the same line; the closing iteration re-runs every Derivation, and the Stop hook refuses a close over an entry with none. Audits must not re-file these.

## Hunted

One line per completed hunt, appended, never rewritten: Hunted: <full commit hash> - <date> - <k> Highs closed. The line is appended by the closing iteration and stands whether or not the Stop hook accepts that close; what certifies the tree is the hook's own accepted record on its metrics line, so a line whose close was refused certifies nothing. The hash has to stay reachable from HEAD: a commit no clone can reach certifies nothing anyone else is able to check. A hunt is not a convergence - the line certifies only that a fresh full audit found no High at that commit - and a later run of either mode audits fresh rather than ratcheting.

A history rewrite that preserves the tree - a squash, a rebase, a filtered export - is answered by appending, never by editing the line it orphaned: `Hunted: <new hash> - <date> - <k> Highs closed (repoints <old hash>, tree unchanged)`. That is legal only when `git rev-parse <old>^{tree}` equals `git rev-parse <new>^{tree}`, and the superseded line stays exactly where it is, because it is the only record left in the tree that the rewrite happened at all. The same iteration appends a dated `## Note` to JOURNAL.md naming both hashes and what was rewritten. A repoint across two different trees is a new claim wearing an old certificate, and it is refused.
