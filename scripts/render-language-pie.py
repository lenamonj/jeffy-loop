"""Render the converged-by-language pie to media/language-pie-{light,dark}.png at 2x.

The slice data is derived from README.md's receipts table at render time, never
typed in, so a rebuild after adding a receipt cannot publish a stale chart.
Run this whenever a converged row is added:

    python scripts/render-language-pie.py
"""

import json
import pathlib
import re
import urllib.parse

from playwright.sync_api import sync_playwright

root = pathlib.Path(__file__).resolve().parent.parent
readme = (root / "README.md").read_text(encoding="utf-8")

# Receipts table rows look like:
#   | [name](evals/x/REPORT.md) | 1,570 | Rust | 30 | **converged** | ... | ... |
ROW = re.compile(
    r"^\|\s*\[[^\]]+\]\(evals/[^)]+\)\s*\|[^|]*\|\s*([^|]+?)\s*\|[^|]*\|\s*\*\*converged\*\*\s*\|",
    re.M,
)

counts = {}
for language in ROW.findall(readme):
    counts[language] = counts.get(language, 0) + 1

total = sum(counts.values())
if total == 0:
    raise SystemExit("no converged rows found in README.md - has the table shape changed?")

marker = re.search(r"<!-- count:converged -->(\d+)<!-- /count -->", readme)
if marker and int(marker.group(1)) != total:
    raise SystemExit(
        f"README says {marker.group(1)} converged but the table has {total} rows; "
        "fix the disagreement before rendering"
    )

# Largest first, ties broken alphabetically so the render is deterministic.
slices = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
data = [{"name": n, "count": c, "pct": round(100 * c / total, 1)} for n, c in slices]
payload = urllib.parse.quote(json.dumps({"total": total, "slices": data}))

print(f"{total} converged across {len(data)} languages: " + ", ".join(f"{d['name']} {d['count']}" for d in data))

src = (root / "media" / "language-pie.html").as_uri()
with sync_playwright() as p:
    browser = p.chromium.launch()
    for theme in ("light", "dark"):
        page = browser.new_page(viewport={"width": 1400, "height": 740}, device_scale_factor=2)
        page.goto(f"{src}?theme={theme}&data={payload}")
        page.wait_for_timeout(300)
        out = root / "media" / f"language-pie-{theme}.png"
        page.screenshot(path=str(out))
        print(f"wrote {out}")
        page.close()
    browser.close()
