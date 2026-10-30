#!/usr/bin/env bash
# Known-answer battery for scripts/render-how-it-works.py and
# scripts/render-running-jeffy.py.  See battery.py for what it grades and why.
#
# Usage: run.sh [tree-root]   (default: this repository)
# Exit 0 and one summary line when every known answer holds, 1 with the
# disagreements, 2 when no Python carrying Playwright can be resolved here.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-$(cd "$here/../../.." && pwd)}"

for cand in python3 python; do
  p="$(command -v "$cand" 2>/dev/null)" || continue
  if "$p" -c 'import playwright' >/dev/null 2>&1; then
    exec "$p" "$here/battery.py" "$root"
  fi
done

if command -v uv >/dev/null 2>&1; then
  exec uv run --no-project --quiet --with playwright python "$here/battery.py" "$root"
fi

echo "NOT RUNNABLE: no python on PATH imports playwright and uv is absent, so this host cannot drive the two render pages" >&2
exit 2
