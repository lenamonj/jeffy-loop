# check-claims battery

Pins the verdicts of `skills/jeffy/hooks/lib/check-claims.sh`, the instrument
that re-runs a project's recorded measurements and says which no longer
reproduce. Every case asserts the exact stdout verdict line, the exact summary
counts on stderr and the exit status together - not one of the three, because this
instrument fails by reporting the wrong count as easily as by reporting the wrong
verdict. No case total is spelled here: the table-driven cases are counted out of
run.sh by a claims line beside this file, and the usage case is pinned by
another, so what carries the population is a measurement rather than a word.

What is pinned, in the order the cases run: a claim that reproduces; a claim
that no longer reproduces, which must be named with both the expected and the
got value; the comparison being the last non-empty line, so a command printing
working output before its answer still compares as its answer; every line of a
claims file being run rather than the first; a malformed line erroring rather
than skipping, since a claims file whose syntax drifted must never read as a
battery with nothing to check; a command that fails erroring with its own exit
status; a row this host cannot derive being skipped rather than checked, with
the summary reporting the skip count beside the checked one, since only that
pair tells a host that compared every row apart from one that derived none of
them; every row shape at once - a match, a mismatch, a command that errors, a
malformed line and a host-unavailable row in one run - which is the only case
that can hold the two identities the output contract states, that checked equals
matched plus mismatched plus errored and that checked plus skipped is every row
read; a battery carrying no claims file checking nothing; and an absent
project root refused at exit 2, which is deliberately distinct from the 1 that
means a claim failed, so a caller can tell a broken invocation from a finding.

What this file records is carried by the claims file beside it rather than
restated here: check-claims.sh exits 2 on an unusable project root, and the
table-driven cases are counted out of run.sh. Neither is asserted as a total here:
the exit status appears above only as the digit its own claims line expects, and
the case count appears nowhere in this file at all. It used to be said to appear
inside the `expected 7 got a` fault string quoted from a driven mutation below,
described as that same claims line's value coming back out of the instrument -
which was a coincidence of two different sevens rather than a mechanism, alpha's
recorded value and the case count having been equal at the moment the sentence
was written. AA2 added a case and they diverged, so the sentence is corrected
here rather than carried: that fault string quotes alpha's claim value and says
nothing about how many cases run. A total written here as a total is a figure no
command returns, and that is exactly how this README came to assert one that was
wrong for two runs.

That rule is no longer prose. A claims line beside this file scans every battery
README for a cardinal standing in a count position - a number word or digit
followed, within a couple of words, by a noun naming this population - and expects
to find none, so a total reintroduced into any battery README is reported by the
very instrument this battery pins, at every gate and every declaration. Ordinals
are outside it by construction: an ordinal names a position and never a
population. It is written as POSIX awk with explicit boundary classes rather than
as a grep carrying the GNU word-boundary extension, which was Z1: on a userland
whose engine does not implement that extension the pattern cannot match, and the
direction it fails in is silence. What awk's match reports is the first site on a
line rather than every site, which is complete for the property being checked,
since the property is that no site exists and a line carrying two still reports. It over-matches on purpose, which is why the sibling README says each
case rather than counting them; a false positive costs one rewording, a false
negative ships the class again. It was driven on the totals this file carried and
on the ones the sibling carried before them, each reported, and on an ordinal
written into the same position, silent.

Observed failing: driven by mutation before it was trusted. Removing the
malformed-line arm so an unrecognised line is skipped instead of erroring makes
the malformed case fault on both the summary and the verdict; changing the
comparison from the last non-empty line to the first makes the third case fault
with `expected 7 got a`. Both were run against the shipped file and the file was
restored byte-identical afterwards. The all-shapes case was driven against the
instrument as it stood before AD1, from a copy taken aside rather than by
checking out over the fix: on the identical fixture it reports 3 checked where
matched plus mismatched plus errored is 4, because a malformed row incremented
errored and continued before the checked increment, so the identity failed on
the one row shape no ordinary run reaches. The skip case was driven the same way and
with an isolating mutation rather than a broad one, because a mutation that
fells every case proves only that the file is read: counting a skipped row as
checked again while leaving the summary's skip field in place fells that case
alone, on the checked count and on nothing else, while deleting the skip field
from the summary fells every case. Both ran in a throwaway clone, so no shipped
file was edited and none needed restoring.
