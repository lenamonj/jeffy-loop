#!/usr/bin/env bash
# run-probe.sh - execute a probe or battery command under a resource ceiling,
# so an instrument is allowed to fail without killing the observer.
#
# A model-authored probe once allocated ~15GB deterministically, three times,
# and the kernel's global OOM response took the whole run with it each time -
# the run never learned its probe was the problem, because the run did not
# survive its probe. This wrapper bounds memory and wall time; a probe killed
# at either ceiling dies alone, the exit is reported with the ceiling named,
# and the iteration files it as an instrument finding and continues.
#
# Usage:   run-probe.sh <command> [args...]
# Ceilings (environment, both optional):
#   JEFFY_PROBE_MEM_MB     memory ceiling in MB   (default 4096)
#   JEFFY_PROBE_TIMEOUT_S  wall ceiling in seconds (default 600)
#
# Mechanism: the memory bound is RSS via a cgroup (systemd-run --user --scope
# -p MemoryMax), because an address-space rlimit (ulimit -v) is the wrong
# knob - Go binaries reserve enormous virtual arenas at startup and JVMs
# reserve far beyond their heap, so a virtual ceiling kills healthy
# instruments while a runaway RSS walks straight past it. Where no user
# manager is reachable the wrapper degrades to the wall ceiling alone and
# says so on stderr, because a probe that can be bounded in one dimension is
# still better observed than unbounded in both.
set -u

if [ "$#" -lt 1 ]; then
  echo "run-probe.sh: usage: run-probe.sh <command> [args...]" >&2
  exit 2
fi

mem_mb="${JEFFY_PROBE_MEM_MB:-4096}"
wall_s="${JEFFY_PROBE_TIMEOUT_S:-600}"
case "$mem_mb" in *[!0-9]*|'') echo "run-probe.sh: JEFFY_PROBE_MEM_MB must be a whole number of MB, got '$mem_mb'" >&2; exit 2 ;; esac
case "$wall_s" in *[!0-9]*|'') echo "run-probe.sh: JEFFY_PROBE_TIMEOUT_S must be a whole number of seconds, got '$wall_s'" >&2; exit 2 ;; esac

# Capability is proven by running a no-op scope, not by asking the manager's
# mood: is-system-running exits nonzero on a merely degraded manager (one
# failed unit anywhere), and this wrapper's first shipped test flip-flopped on
# exactly that while real scopes worked fine throughout.
have_scope=0
if command -v systemd-run >/dev/null 2>&1 \
  && systemd-run --user --scope --quiet true >/dev/null 2>&1; then
  have_scope=1
fi

if [ "$have_scope" -eq 1 ]; then
  systemd-run --user --scope --quiet \
    -p "MemoryMax=${mem_mb}M" -p MemorySwapMax=0 \
    timeout "${wall_s}s" "$@"
  rc=$?
else
  echo "run-probe.sh: no user manager reachable, memory ceiling unavailable; running under the ${wall_s}s wall ceiling alone." >&2
  timeout "${wall_s}s" "$@"
  rc=$?
fi

if [ "$rc" -eq 124 ]; then
  echo "run-probe.sh: probe exceeded the ${wall_s}s wall ceiling and was ended; a probe that cannot finish in bounded time is an instrument finding about the probe." >&2
elif [ "$rc" -eq 137 ] && [ "$have_scope" -eq 1 ]; then
  echo "run-probe.sh: probe was killed under the ${mem_mb}MB memory ceiling (SIGKILL); a probe that exhausts bounded memory is an instrument finding about the probe, and the run continues." >&2
elif [ "$rc" -ne 0 ]; then
  echo "run-probe.sh: probe exited $rc under ceilings ${mem_mb}MB / ${wall_s}s." >&2
fi
exit "$rc"
