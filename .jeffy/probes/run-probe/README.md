# run-probe battery

Pins the resource ceilings of `skills/jeffy/hooks/lib/run-probe.sh`: a probe is
allowed to fail without taking the run with it, so both ceilings must really
bind and neither may launder the probe's own exit status.

Both documented parameters are exercised at two values that change the outcome
rather than at one value that merely runs: the same `sleep 5` ends at 124 under
`JEFFY_PROBE_TIMEOUT_S=1` and at 0 under `10`, and the same 320MB allocation is
SIGKILLed at 137 under `JEFFY_PROBE_MEM_MB=64` and completes at 0 under `1024`.
The negative sides are here too, because a ceiling that silently accepts a typo
is a ceiling that is off: a non-numeric value for either parameter is refused at
exit 2 before the probe runs.

The wrapper's default ceilings are 4096MB / 600s, and the battery measures that
pair out of the wrapper's own diagnostic rather than reading it from this file.

Where no systemd user scope is reachable the memory dimension is not exercised,
and the battery says so on stdout instead of passing over it in silence.

Observed failing: written against the shipped file and driven by mutation before
it was trusted. Changing the wrapper's `wall_s` default from 600 to 900 makes the
default-ceilings case fault with the pair it actually measured, and deleting the
`rc -eq 124` branch makes the wall-ceiling diagnostic case fault while the exit
status alone still passes - which is the case that matters, because a ceiling
that kills without saying why is indistinguishable from a probe that crashed.
