# The upstream-disclosure practice

These rules were paid for across four real maintainer threads: bat #3862,
chalk #687, fasthttp #2343, and PapaParse #1133-#1136 / yfinance #2927. Two
of them opened with skeptical maintainers and ended in merges. What follows
is the disclosure practice those threads taught, including the mistakes -
because the guardrails below each cost a public correction to learn.

## Disclosure shape

- Lead with the reproduction and the failing output, not the tool.
- One finding per PR; each branch cut independently from their master.
- Regression test proven red on their master; never soften a test to ease
  review.
- Answer review with an additional commit, never amend + force-push.
- Own mistakes plainly (the yfinance broken-repro recovery).
- Tool disclosure at the end.

## Before you open the PR

Each line below names the failure that wrote it.

- Every repro or script in the PR body has been run in exactly the form
  pasted, and its stated output is that run's real output. A trimmed-down
  version is new code and unverified until executed as written. (yfinance
  #2927: the thread repro was broken; the recovery cost an apology and an
  offline fixture.)
- Every prose claim about what the test asserts is checked against what the
  test actually asserts, clause by clause. State the oracle exactly.
  (fasthttp #2343: our receipt said the test compares against
  strconv.ParseInt; it accepts a leading sign ParseInt would reject, the
  maintainer refuted it in review, and the wrong claim was live in README and
  receipt for three days.)
- If the diff touches a hot path, run the project's own benchmark suite
  before and after, and put the numbers in the PR body - theirs, not ours.
  Never let the maintainer be the first to measure. (fasthttp: a 60 percent
  regression we never measured, traced to Go inline cost 79 blown to 84 over
  a budget of 80 - and the obvious explanation, added arithmetic, was wrong.
  Profile before conceding a cause.)
- The regression test holds on every architecture and platform the project
  supports, or says explicitly why it is pinned. (fasthttp: the submitted
  test table pinned the bug only on 64-bit.)

## After the merge

- A merge is the moment to re-read the whole receipt, not just flip the
  table cell: diff what the merged code actually asserts against what the
  published prose says it asserts, and correct in the open when they differ.
- The count sweep covers surfaces that are not files: GitHub About, release
  bodies, topics, social preview, profile README, platform bios. grep sees
  none of them. (The About text said 2 merges at 3.)
- Merged is not shipped: never write that a fix shipped until a release tag
  contains it; when the tag cuts, add the "shipped in vX" line.
