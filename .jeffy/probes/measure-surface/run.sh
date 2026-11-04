#!/usr/bin/env bash
# Known-answer battery for skills/jeffy/hooks/lib/measure-surface.sh.
# Builds one throwaway git tree whose counted line total is known by
# construction, then asserts the measurement, every documented parameter at
# two or more values, and each documented exit code.
set -u
ms_root="${JEFFY_PROBE_ROOT:-$PWD}"
ms_sh="$ms_root/skills/jeffy/hooks/lib/measure-surface.sh"
[ -f "$ms_sh" ] || { echo "measure-surface battery: no $ms_sh"; exit 2; }
ms_ok=0; ms_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then ms_ok=$((ms_ok + 1)); else
    ms_bad=$((ms_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}
ms_tmp="$(mktemp -d)" || exit 2
trap 'rm -rf "$ms_tmp"' EXIT

# The fixture. Counted: a.py 10, b.sh 5, vendored_api.go 7, "with space.py" 4,
# -dash.py 6 = 32 lines in 5 files. Not counted: notes.md by extension,
# vendor/v.py by directory, link.py as a symlink, sub as a gitlink.
ms_p="$ms_tmp/proj"; mkdir -p "$ms_p/vendor"
( cd "$ms_p" && git init -q . && git config user.email b@b.b && git config user.name b )
ms_fill() { n=0; : > "$1"; while [ "$n" -lt "$2" ]; do echo "x" >> "$1"; n=$((n + 1)); done; }
ms_fill "$ms_p/a.py" 10
ms_fill "$ms_p/b.sh" 5
ms_fill "$ms_p/notes.md" 3
ms_fill "$ms_p/vendor/v.py" 100
ms_fill "$ms_p/vendored_api.go" 7
ms_fill "$ms_p/with space.py" 4
ms_fill "$ms_p/-dash.py" 6
ms_link=1
ln -s a.py "$ms_p/link.py" 2>/dev/null || ms_link=0
( cd "$ms_p" && git add -A -- . >/dev/null 2>&1 )
# A gitlink at mode 160000, with no submodule behind it: what a tree records
# for a submodule that was never initialised, which is the shape wc chokes on.
( cd "$ms_p" && git update-index --add --cacheinfo "160000,$(git rev-parse HEAD 2>/dev/null || printf '%040d' 0),sub" >/dev/null 2>&1 )
( cd "$ms_p" && git commit -q -m fixture >/dev/null 2>&1 )

ms_run() { bash "$ms_sh" "$@" 2>"$ms_tmp/err"; }

# 1. the measurement itself, and the file count beside it
ms_out="$(ms_run "$ms_p")"; ms_rc=$?
ck "exit on a measured tree" 0 "$ms_rc"
if [ "$ms_link" = 1 ]; then
  ck "measurement with a symlink and a gitlink present" "lines=32 files=5" "$(printf '%s' "$ms_out" | head -n 1)"
else
  echo "SKIP symlink arm: this filesystem made no symlink"
  ck "measurement with a gitlink present" "lines=32 files=5" "$(printf '%s' "$ms_out" | head -n 1)"
fi
# 2. the five-largest listing: one row per counted file, largest first
ck "largest-file rows" 5 "$(printf '%s\n' "$ms_out" | tail -n +2 | grep -c .)"
ck "largest file first" "10 a.py" "$(printf '%s\n' "$ms_out" | sed -n 2p)"
# 3. vendored directory skipped, vendored-prefixed file kept
ck "vendor/ not among the rows" 0 "$(printf '%s\n' "$ms_out" | grep -c 'vendor/v.py')"
ck "vendored_api.go kept" 1 "$(printf '%s\n' "$ms_out" | grep -c 'vendored_api.go')"
# 4. a path with a space and a path that looks like a flag both survive
ck "path with a space kept" 1 "$(printf '%s\n' "$ms_out" | grep -c 'with space.py')"
ck "flag-shaped path kept" 1 "$(printf '%s\n' "$ms_out" | grep -c -- '\-dash.py')"

# 5. --ceiling at two values either side of the measurement, and at equality
ms_run "$ms_p" --ceiling 31 >"$ms_tmp/over" 2>&1; ck "exit over the ceiling" 3 "$?"
ck "refusal names the measurement" 1 "$(grep -c 'SURFACE OVER CEILING: 32 tracked source lines in 5 files' "$ms_tmp/over")"
ck "refusal names the headroom ceiling" 1 "$(grep -c -- '--max-surface 10000' "$ms_tmp/over")"
ms_run "$ms_p" --ceiling 32 >/dev/null 2>&1; ck "exit at the ceiling exactly" 0 "$?"
ms_run "$ms_p" --ceiling 0 >/dev/null 2>&1; ck "exit with the ceiling off" 0 "$?"
# 6. bad usage, each documented shape
ms_run "$ms_p" --ceiling abc >/dev/null 2>&1; ck "exit on a non-numeric ceiling" 64 "$?"
ms_run "$ms_p" --ceiling 300000000000000 >/dev/null 2>&1; ck "exit on an absurd ceiling" 64 "$?"
ms_run "$ms_p" --ceiling >/dev/null 2>&1; ck "exit on a ceiling with no value" 64 "$?"
ms_run "$ms_p" --nope >/dev/null 2>&1; ck "exit on an unknown argument" 64 "$?"
bash "$ms_sh" >/dev/null 2>&1; ck "exit with no root" 64 "$?"
# 7. not a git work tree
mkdir -p "$ms_tmp/plain"
ms_run "$ms_tmp/plain" >/dev/null 2>&1; ck "exit outside a git work tree" 2 "$?"

if [ "$ms_bad" -eq 0 ]; then
  echo "measure-surface battery: $ms_ok/$ms_ok checks passed"
  exit 0
fi
echo "measure-surface battery: $ms_bad of $((ms_ok + ms_bad)) checks failed"
exit 1
