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

# Wall ceiling, only where a tool can enforce it. The same probe under two
# values of JEFFY_PROBE_TIMEOUT_S must end differently, or the parameter does
# nothing and that is a finding. Where neither timeout(1) nor gtimeout(1) is on
# PATH the wrapper degrades by contract, exactly as it does for memory, and what
# is asserted there is that it says so - a silent degradation is the failure.
if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
  JEFFY_PROBE_TIMEOUT_S=1 bash "$P" sleep 5 >/dev/null 2>"$e"; ck "wall ceiling kills" 124 $?
  cktext "wall ceiling names itself" "exceeded the 1s wall ceiling" "$e"
  JEFFY_PROBE_TIMEOUT_S=10 bash "$P" sleep 5 >/dev/null 2>"$e"; ck "wall ceiling admits" 0 $?
else
  bash "$P" true >/dev/null 2>"$e"
  cktext "wall degradation is announced" "wall ceiling unavailable" "$e"
  echo "note: no timeout(1) or gtimeout(1) reachable, wall ceiling not exercised on this host"
fi

# Memory ceiling, only where a user scope is reachable. Where it is not, the
# wrapper degrades by contract and the battery says so rather than passing
# silently over a dimension it never tested.
if command -v systemd-run >/dev/null 2>&1 && systemd-run --user --scope --quiet true >/dev/null 2>&1; then
  # The allocator is dd rather than an interpreter: the loop requires neither
  # systemd-run nor python3, and guarding one while depending on the other is
  # the defect Z1 closed. dd reads one 320MB block from /dev/zero, which needs
  # the whole buffer resident, and its size is written in plain bytes because
  # the M multiplier is not POSIX.
  a=(dd if=/dev/zero of=/dev/null bs=320000000 count=1)
  JEFFY_PROBE_MEM_MB=64 bash "$P" "${a[@]}" >/dev/null 2>"$e"; ck "memory ceiling kills" 137 $?
  cktext "memory ceiling names itself" "killed under the 64MB memory ceiling" "$e"
  JEFFY_PROBE_MEM_MB=1024 bash "$P" "${a[@]}" >/dev/null 2>"$e"; ck "memory ceiling admits" 0 $?
else
  bash "$P" true >/dev/null 2>"$e"
  cktext "memory degradation is announced" "no user manager reachable" "$e"
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

# AE12: the pair names the ceilings that were enforced, never the ones that
# were configured, so the degraded arm is driven here rather than assumed. PATH
# is emptied rather than filtered - everything the wrapper needs of its own is a
# bash builtin - and the probe is invoked through an absolute interpreter so the
# empty PATH cannot reach it. Both halves must read none: on this shape the
# wrapper enforces neither, and it used to answer 4096MB / 0s two lines under
# its own "no ceiling at all".
nop="$(mktemp -d)"
PATH="$nop" "$BASH" "$P" "$BASH" -c 'exit 3' >/dev/null 2>"$e"; ck "degraded host passes the status through" 3 $?
dg="$(sed -n 's/.*under ceilings \(.*\)\./\1/p' "$e")"
if [ "$dg" != "none / none" ]; then
  echo "FAIL degraded host names only the ceilings it enforced: expected 'none / none', got '$dg'"
  fails=$((fails + 1))
fi
rmdir "$nop"

# The defaults the README states, measured from the wrapper rather than read.
# Both halves of the pair are what the wrapper resolved rather than constants,
# so a fixed expectation here would fail on exactly the hosts the wrapper
# degrades for - and a fixed memory half was what this block carried until
# AE12, which is how the battery came to pin a figure nothing had applied.
bash "$P" bash -c 'exit 3' >/dev/null 2>"$e"
d="$(sed -n 's/.*under ceilings \(.*\)\./\1/p' "$e")"
if command -v systemd-run >/dev/null 2>&1 && systemd-run --user --scope --quiet true >/dev/null 2>&1; then
  wm="4096MB"
else
  wm="none"
fi
if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
  ww="600s"
else
  ww="none"
fi
want="$wm / $ww"
if [ "$d" != "$want" ]; then
  echo "FAIL default ceilings: expected '$want', got '$d'"; fails=$((fails + 1))
fi
rm -f "$e"
[ "$fails" -eq 0 ] && echo "run-probe battery ok: default ceilings $d" || echo "run-probe battery: $fails failure(s)"
[ "$fails" -eq 0 ]
