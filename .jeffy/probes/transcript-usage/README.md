# transcript-usage

A known-answer battery for `skills/jeffy/hooks/lib/transcript-usage.sh`, the
token and live-context reader the Stop hook sources for every turn record.

## Why this row needed a battery rather than a reading

The file landed in 1.28.0 and no Surface inventory row claimed it until run 27
iteration 1, where PLAN.md's coverage command returned it as the one tracked
path outside the map. Staleness could not have found it: a row that does not
exist cannot go stale, which is the half of an honest inventory that only the
coverage command sees.

It is a surface that computes values, so PLAN.md's rule is a correctness check
per function family and never a liveness probe. Every figure it prints reaches
a user through `jeffy-stats`, and a wrong one is returned without complaint.

## What the harness already does, and the gap that justifies this

`scripts/validate.sh` carries four scenarios over this file: the aggregate
figures on one fixture, one `since` value, an unreadable path, and a path
written with backslashes. Those four are not re-asserted here.

What they cannot establish is one line of arithmetic. Their fixture's
`context_tokens_last` and `context_tokens_peak` are both 30005, so an
implementation that returns `last` for both passes the harness unchanged. The
fixture here is built so the two differ - 7300 against 52200 - and the
`peak` mutation below is the proof that the arm sees it.

Two more properties were unestablished for the same reason. Context is
documented as the main session's alone, and the harness's sub-agent entry
carries a window smaller than the main peak, so letting sub-agents in would
not have moved its answer; here the sub-agent's own window is 901500 against
a main peak of 52200. And the `since` comparison is `>=`, so a message stamped
exactly at the bound is kept; the harness drives one bound and never its
boundary.

## The fixture, and where its answers come from

One main transcript and one sub-agent file beside it. Every figure the arms
assert is a sum over these taken by hand before the reader ran:

| id | file | stamp | model | in | create (1h) | read | out | window |
|:--|:--|:--|:--|--:|--:|--:|--:|--:|
| A | main | :02 | M1 | 100 | 1000 (400) | 5000 | 10 | 6100 |
| B | main | :04 | M1 | 200 | 2000 (0) | 50000 | 20 | 52200 |
| B | main | :05 | M1 | repeated verbatim, as a transcript repeats a message per content block | | | | |
| E | main | none | M1 | 1 | 0 | 2 | 3 | 3 |
| C | main | :06 | M2 | 300 | 0, no `cache_creation` object | 7000 | 30 | 7300 |
| D | main | :06 | M1 | no `usage` at all | | | | |
| S | main | :07 | `<synthetic>` | all zero | | | | |
| G | sub | :08 | M3 | 1000 | 500 (500) | 900000 | 100 | 901500 |

Five messages, not eight: `B` is counted once, `D` carries no usage and `S` is
an API failure. So 1601 input, 2600 five-minute, 900 one-hour, 962002 read,
163 output. `E` sits before `C` on purpose: the last main entry in file order
then has the smaller window, so a reader taking the file's last line answers 3
where the last picked entry answers 7300.

The one documented parameter is driven at four values whose outputs differ: no
bound (5 messages), a bound equal to `C`'s own stamp (2, the inclusive side),
one second past it (1, the exclusive side, and a main file with no picked
entry so context falls to 0), and a bound past everything (0 messages, every
sum 0, the model list empty). `E` carries no stamp at all, so it is counted
without a bound and dropped with one - the reader compares `""` against the
bound - and that is driven both ways on its own.

## Seen to fail, six ways

Each mutation is staged on a copy, confirmed to have landed, confirmed to
parse with `bash -n`, and read against a baseline re-run on that same stage,
which reports 28/28 there. Three isolate, and three move numbers that several
arms read; which ones fall together is recorded rather than tidied away.

| mutation | arms it falls |
|:--|--:|
| `unique_by(.id)` dropped, so a repeated message counts twice | 5 |
| `- $w1h` removed, so the five-minute tier carries the one-hour total | 1 |
| `select(.src == "main")` dropped, so sub-agents reach the context | 4 |
| `max` replaced by `last`, so the peak is a copy of the last reading | 2 |
| `>=` narrowed to `>`, so a message stamped at the bound is dropped | 2 |
| the `<synthetic>` guard replaced by `true` | 5 |

The `peak` mutation is the one that matters most: it is the shape the harness
cannot see, and it falls the peak arm and the sub-agent-window arm and nothing
else.

## The expected total

`run.sh` records 27 executed checks, or 28 where `chmod 000` blocks this
user's own read. `grep -c '^ *ck "' run.sh` returns 28: the 26 unconditional
arms, the conditional unreadable-file arm, and the arm that compares the
executed total against the figure worked out beforehand. The unreadable-file
arm derives its own guard by testing `[ -r ]` on the file it just chmodded
rather than by reading an exit code, because under root and on a filesystem
that drops modes the arm would otherwise pass for the wrong reason.

## What it cannot reach

- Nothing here reads a real Claude Code transcript. The fixtures define the
  schema this battery believes in, and that schema was taken from the reader's
  own `jq` program and the harness's fixture rather than from a live file.
- The two roles are both driven, sourced and executed, but the Stop hook's own
  use of the sourced function is not: `.jeffy/probes/stop-hook` owns the hook.
- The backslashed-path reading stays with the harness, which has the `cygpath`
  branch for it; duplicating it here would give that reading a second source rather than adding coverage.
- Nothing asserts that the figures are right about a session's real billing.
  The reader's own contract is what is graded: counted once per message id,
  tiers apart, context from the main file, cumulative since a bound.
