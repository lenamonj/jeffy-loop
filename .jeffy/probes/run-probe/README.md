# run-probe battery

Pins the resource ceilings of `skills/jeffy/hooks/lib/run-probe.sh`: a probe is
allowed to fail without taking the run with it, so both ceilings must really
bind and neither may launder the probe's own exit status.

Both documented parameters are exercised at two values that change the outcome
rather than at one value that merely runs, on a host that can enforce them: the
same `sleep 5` ends at 124 under `JEFFY_PROBE_TIMEOUT_S=1` and at 0 under `10`,
and the same 320MB allocation is SIGKILLed at 137 under `JEFFY_PROBE_MEM_MB=64`
and completes at 0 under `1024`. Where a ceiling cannot be enforced its dimension
is not exercised at all and what is asserted instead is the wrapper's own notice,
which is the whole of the paragraph on host dependence further down.
The negative sides are here too, because a ceiling that silently accepts a typo
is a ceiling that is off: a non-numeric value for either parameter is refused at
exit 2 before the probe runs. The allocator is dd reading one block from
/dev/zero, sized in plain bytes: it was an interpreter until Z1, and an
instrument that guards one tool the loop does not require while depending on
another is guarded in name only. On a host carrying a user scope but no
interpreter the old form reported that the ceiling did not bind, which is a
mismatch the gate is instructed to reject on.

The wrapper's default ceilings are 4096MB and 600s, and the battery measures the
pair out of the wrapper's own diagnostic rather than reading it from this file -
which is why the measured pair, and not the defaults, is what varies by host: the
wrapper reports the wall figure it resolved, and it resolves 0 where it found no
tool to enforce one.
Every figure stated above is carried by a line in the claims file beside this one
and executed by check-claims.sh, and the enumeration is written out here so a
figure added to the prose without a line beside it is visible rather than covered
by a universal. No total is written here, and that is the rule the check-claims
README beside this one records rather than a stylistic choice: a total is a
population no command returns, and one written here would be the very thing this
paragraph asserts every figure escapes. What is written is each figure against the
claims line that carries it - the 0 of the wall-ceiling admit run, the 0 of the
memory-ceiling admit run, the exit 2 of a refused ceiling, and the ones recorded as
verdicts rather than as numbers, defaults-ok, wall-ok and mem-ok, for the reason
below. Every figure stated in this file resolves to a claims value, a value
inside a claims command, an input to a mutation the Observed failing record names,
or the count of values the sweep bar exercises a parameter at, which X3 classified
by extracting them. That reading covers less than the sentence used to claim: it
said every integer and number word, and running the extraction reports a number
word used as an English selector rather than as a figure, which no such class
resolves. The narrower property is enforced rather than classified, by the claims
line beside the check-claims README: nothing in this file counts this battery's
claims.

The wall kill, the memory kill and the defaults pair were host-dependent expected
values until V2, and a claims file that records one blocks convergence on the hosts
the wrapper exists to degrade for. They are named rather than counted here for the
same reason no total is: a count of claims is a figure no claims line carries.
On a host with no timeout(1) or gtimeout(1) the same sleep 5 exits 0 and not 124,
on a host with no reachable user manager the same allocation exits 0 and not 137,
and the wrapper then reports its defaults as 4096MB / 0s and not 4096MB / 600s,
because it sets the wall ceiling to 0 when it cannot enforce one. check-claims.sh
would report MISMATCH for each of them, and the evaluator gate is instructed to treat
a MISMATCH as a REJECT reason. Each now asserts the whole contract
rather than one host's half of it: where the ceiling can be enforced it must bind,
and where it cannot the wrapper must say so, which is the same guard run.sh applies
to the dimension it cannot exercise. The token is the answer either way, and the
mismatch text carries the real exit status or the missing notice, so nothing is
laundered into a pass. Driven on both shapes rather than reasoned about: on a PATH
carrying no timeout(1), and on one carrying neither timeout(1) nor systemd-run,
every claim matches; and with the wrapper's degradation notices removed, the wall and
memory verdicts each mismatch naming the notice that went missing.

Where no systemd user scope is reachable the memory dimension is not exercised,
and where neither timeout(1) nor gtimeout(1) is on PATH the wall dimension is not
either. The battery says so on stdout in each case instead of passing over a
dimension in silence, and in both it asserts the degradation was announced on
stderr, because a ceiling that turns itself off quietly is the failure this whole
instrument exists to make visible. The wall half of that was missing until V2:
run.sh guarded memory and ran the wall cases unconditionally, so the battery would
have failed outright on a stock macOS host rather than reporting what it skipped.

Observed failing: written against the shipped file and driven by mutation before
it was trusted. Changing the wrapper's `wall_s` default from 600 to 900 makes the
default-ceilings case fault with the pair it actually measured, and deleting the
`rc -eq 124` branch makes the wall-ceiling diagnostic case fault while the exit
status alone still passes - which is the case that matters, because a ceiling
that kills without saying why is indistinguishable from a probe that crashed.
