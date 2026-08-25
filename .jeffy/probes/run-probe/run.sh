#!/usr/bin/env bash
# Known-answer battery for skills/jeffy/hooks/lib/run-probe.sh.
# Both documented parameters are exercised at two values that must change the
# outcome, plus the negative and boundary sides. Liveness is never the test:
# every case asserts a specific exit status and, where the wrapper promises a
# diagnostic, the text of it.
set -u
P="skills/jeffy/hooks/lib/run-probe.sh"
fails=0
ck() { # ck <label> <expected rc> <actual rc>
  if [ "$2" = "$3" ]; then return 0; fi
  echo "FAIL $1: expected exit $2, got $3"; fails=$((fails + 1))
}
cktext() { # cktext <label> <needle> <file>
  if grep -q -- "$2" "$3"; then return 0; fi
  echo "FAIL $1: stderr does not carry '$2'"; fails=$((fails + 1))
}
e=$(mktemp)

# Wall ceiling. The same probe under two values of JEFFY_PROBE_TIMEOUT_S must
# end differently, or the parameter does nothing and that is a finding.
JEFFY_PROBE_TIMEOUT_S=1 bash "$P" sleep 5 >/dev/null 2>"$e"; ck "wall ceiling kills" 124 $?
cktext "wall ceiling names itself" "exceeded the 1s wall ceiling" "$e"
JEFFY_PROBE_TIMEOUT_S=10 bash "$P" sleep 1 >/dev/null 2>"$e"; ck "wall ceiling admits" 0 $?

# Memory ceiling, only where a user scope is reachable. Where it is not, the
# wrapper degrades by contract and the battery says so rather than passing
# silently over a dimension it never tested.
if command -v systemd-run >/dev/null 2>&1 && systemd-run --user --scope --quiet true >/dev/null 2>&1; then
  a='python3 -c "b=bytearray(320*1024*1024); b[::4096]=b\"x\"*(len(b)//4096); print(len(b))"'
  JEFFY_PROBE_MEM_MB=64 bash "$P" bash -c "$a" >/dev/null 2>"$e"; ck "memory ceiling kills" 137 $?
  cktext "memory ceiling names itself" "killed under the 64MB memory ceiling" "$e"
  JEFFY_PROBE_MEM_MB=1024 bash "$P" bash -c "$a" >/dev/null 2>"$e"; ck "memory ceiling admits" 0 $?
else
  echo "note: no user scope reachable, memory ceiling not exercised on this host"
fi

# Negative sides: a ceiling that is not a whole number is refused before the
# probe runs, so a typo never reads as an unbounded run.
JEFFY_PROBE_TIMEOUT_S=abc bash "$P" true >/dev/null 2>"$e"; ck "non-numeric wall refused" 2 $?
JEFFY_PROBE_MEM_MB=-1 bash "$P" true >/dev/null 2>"$e"; ck "negative memory refused" 2 $?
bash "$P" >/dev/null 2>"$e"; ck "no command refused" 2 $?

# Pass-through: the wrapper is not allowed to launder a probe's own status.
bash "$P" bash -c 'exit 3' >/dev/null 2>"$e"; ck "exit status passes through" 3 $?
cktext "nonzero exit names the ceilings" "probe exited 3 under ceilings" "$e"
bash "$P" true >/dev/null 2>"$e"; ck "clean probe passes" 0 $?

# The defaults the README states, measured from the wrapper rather than read.
bash "$P" bash -c 'exit 3' >/dev/null 2>"$e"
d="$(sed -n 's/.*under ceilings \(.*\)\./\1/p' "$e")"
if [ "$d" != "4096MB / 600s" ]; then
  echo "FAIL default ceilings: expected '4096MB / 600s', got '$d'"; fails=$((fails + 1))
fi
rm -f "$e"
[ "$fails" -eq 0 ] && echo "run-probe battery ok: default ceilings $d" || echo "run-probe battery: $fails failure(s)"
[ "$fails" -eq 0 ]
