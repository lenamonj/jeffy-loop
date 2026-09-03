#!/usr/bin/env bash
# Known-answer battery for the one value-computing surface in this repository:
# the per-language counts and percentages scripts/render-language-pie.py
# derives from the scorecard in evals/README.md, and the alt text that page
# publishes from them. Check Jb held these together until 1.14.0 dropped it as
# README bookkeeping; between then and A1 nothing did, while PLAN.md went on
# naming Jb as the reason no inventory row here needed a battery.
#
# Usage: run.sh [tree-root]   (default: this repository)
# Exit 0 and one summary line when the published alt text is exactly what the
# script's own derivation produces; non-zero with the disagreement otherwise.
set -eu
root="${1:-$(cd "$(dirname "$0")/../../.." && pwd)}"
python3 - "$root" <<'PY'
import re, sys, pathlib

root = pathlib.Path(sys.argv[1])
page = root / "evals" / "README.md"
readme = page.read_text(encoding="utf-8")

# The row shape is the one render-language-pie.py uses; keeping the two in step
# is half of what this battery is for, so a table reshape that blinds the
# script blinds this too and the emptiness guard below is what catches it.
# A converged row is a Fixed row whose details cell does not open with the
# italic *audit* tag.
ROW = re.compile(
    r"^\|\s*[^|]+?\s*\|\s*([^|]+?)\s*\|\s*(\[details\]\([^)]*\)[^|]*)\|\s*Fixed\s*\|",
    re.M,
)
counts = {}
for language, details in ROW.findall(readme):
    if " - *audit" in details:
        continue
    counts[language] = counts.get(language, 0) + 1
total = sum(counts.values())
if total == 0:
    sys.exit("BROKEN: no converged rows matched in %s, so this battery compared nothing" % page.name)

slices = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
regen = "Pie chart of the %d converged public targets by language: " % total + ", ".join(
    "%s %d at %s percent" % (n, c, round(100 * c / total, 1)) for n, c in slices
) + "."

m = re.search(r'alt="(Pie chart[^"]*)"', readme)
if not m:
    sys.exit("BROKEN: evals/README.md publishes no language-pie alt text for this battery to compare")
published = m.group(1)

fail = 0
if published != regen:
    print("FAIL alt text disagrees with the table")
    print("  published:   " + published)
    print("  regenerated: " + regen)
    fail = 1

# The two count markers restate the same totals; a wrong one ships silently.
for label, want in (("converged", total), ("languages", len(slices))):
    got = re.findall(r"<!-- count:%s -->(\d+)<!-- /count -->" % label, readme)
    if not got:
        print("FAIL no count:%s marker in evals/README.md" % label)
        fail = 1
    elif any(int(g) != want for g in got):
        print("FAIL count:%s markers %s disagree with the table's %d" % (label, got, want))
        fail = 1

if fail:
    sys.exit(1)
print("language-pie battery ok: %d converged across %d languages, alt text and both count markers agree"
      % (total, len(slices)))
PY
