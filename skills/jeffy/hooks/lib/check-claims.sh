#!/usr/bin/env bash
# check-claims.sh - execute every recorded measurement a battery claims, and
# say which ones no longer reproduce.
#
# A rule that reads "re-run every recorded measurement" is only as good as
# the enumeration of that set, and through 1.17.0 the enumeration was a grep
# the audit invented: classnames drew four gate REJECTs on README counts its
# own procedures contradicted, three of them spelled in words the grep never
# matched, and the audit then asserted completeness over the set it had
# looked at. The set is now a directory read: each battery's `claims` file,
# one line per measurement, `expect <value> :: <command>`. A battery with no
# recorded measurement holds the single line `none`.
#
# Usage:   check-claims.sh [<project root>] [<battery name>...]
# Output:  one line per claim - MATCH <battery>: <value>
#                               MISMATCH <battery>: expected <value> got <last stdout line>
#                               ERROR <battery>: exit <rc> (<command>)
#          then `claims: <n> checked, <m> mismatched, <e> errored` on stderr.
# Exit:    0 when every claim matches, 1 on any MISMATCH or ERROR, 2 on usage.
#
# Each command runs from the project root under run-probe.sh's ceiling, so a
# claim that hangs or allocates without bound dies alone. The last non-empty
# stdout line, trimmed, is compared to <value> exactly: a claim whose command
# prints more than its answer records that in the command (`| tail -n 1`).
# This script executes model-authored commands and is therefore called by
# the iteration and by the gate, never by the Stop hook (P1-50).
set -u

root="${1:-.}"
[ -d "$root" ] || { echo "check-claims.sh: no such directory: $root" >&2; exit 2; }
shift $(( $# > 0 ? 1 : 0 ))
root="$(cd "$root" && pwd)"
# Absolute, because every claim runs from the project root and a relative
# path would resolve against that root instead of against this script.
probe_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
probe="$probe_dir/run-probe.sh"
[ -f "$probe" ] || { echo "check-claims.sh: run-probe.sh not found beside this script" >&2; exit 2; }

if [ "$#" -gt 0 ]; then
  dirs=""
  for b in "$@"; do dirs="$dirs$root/.jeffy/probes/$b
"; done
else
  dirs="$(find "$root/.jeffy/probes" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
"
fi

checked=0; mism=0; err=0
while IFS= read -r d; do
  [ -n "$d" ] || continue
  bat="${d##*/}"
  [ -f "$d/claims" ] || continue
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|none) continue ;; esac
    case "$line" in
      'expect '*' :: '*) ;;
      *) echo "ERROR $bat: malformed claims line '$line'"; err=$((err + 1)); continue ;;
    esac
    rest="${line#expect }"
    want="${rest%% :: *}"
    cmd="${rest#* :: }"
    checked=$((checked + 1))
    got="$(cd "$root" && bash "$probe" bash -c "$cmd" 2>/dev/null)"
    rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "ERROR $bat: exit $rc ($cmd)"; err=$((err + 1)); continue
    fi
    got="$(printf '%s\n' "$got" | sed '/^[[:space:]]*$/d' | tail -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [ "$got" = "$want" ]; then
      echo "MATCH $bat: $want"
    else
      echo "MISMATCH $bat: expected $want got $got"; mism=$((mism + 1))
    fi
  done < "$d/claims"
done <<EOF2
$dirs
EOF2

echo "claims: $checked checked, $mism mismatched, $err errored" >&2
[ "$mism" -eq 0 ] && [ "$err" -eq 0 ]
