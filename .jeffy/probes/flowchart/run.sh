#!/usr/bin/env bash
# Known-answer battery for scripts/render-flowchart.py.  See battery.py.
#
# Usage: run.sh [tree-root]   (default: this repository)
# Exit 0 and one summary line when every known answer holds, 1 with the
# disagreements, 2 when the host cannot supply Playwright or a working node.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-$(cd "$here/../../.." && pwd)}"

# render_svg shells out to npx, so a node has to be on PATH that actually runs.
# A dangling symlink left by an nvm upgrade resolves under command -v and then
# fails to exec, which is the state this host is in, so the resolution is by
# execution rather than by lookup.
if ! node --version >/dev/null 2>&1; then
  for bin in "$HOME"/.nvm/versions/node/*/bin; do
    if [ -x "$bin/node" ] && "$bin/node" --version >/dev/null 2>&1; then
      PATH="$bin:$PATH"
      export PATH
      break
    fi
  done
fi
if ! node --version >/dev/null 2>&1 || ! npx --version >/dev/null 2>&1; then
  echo "NOT RUNNABLE: no working node/npx on PATH, so mermaid-cli cannot render the chart" >&2
  exit 2
fi

for cand in python3 python; do
  p="$(command -v "$cand" 2>/dev/null)" || continue
  if "$p" -c 'import playwright' >/dev/null 2>&1; then
    exec "$p" "$here/battery.py" "$root"
  fi
done

if command -v uv >/dev/null 2>&1; then
  exec uv run --no-project --quiet --with playwright python "$here/battery.py" "$root"
fi

echo "NOT RUNNABLE: no python on PATH imports playwright and uv is absent" >&2
exit 2
