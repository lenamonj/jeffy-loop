"""Render media/flowchart.mmd to the two README PNGs, with directional
arrowheads repeated along the long edges.

Why this script exists: mermaid only draws an arrowhead at an edge's
endpoint, so on the long sweeps (the re-feed loop back to the top of the
iteration, the turn-ends drop into the engine) the direction of flow is
invisible until the far end. SVG marker-mid repeats the arrowhead at every
curve vertex, but Chromium honors marker-mid only as an element attribute,
not as CSS, so themeCSS cannot carry it and mmdc's own PNG export cannot
produce it. This script renders the SVGs with mmdc, injects the attribute
on the named edges, and rasterizes both themes at 3x with Playwright.

Usage: python scripts/render-flowchart.py  (from the repo root)
"""

import re
import subprocess
import sys
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
MMD = ROOT / "media" / "flowchart.mmd"

# Edge ids follow L_<from>_<to>_<n> over declaration order in the .mmd.
# These are the long edges where flow direction gets lost without help.
LONG_EDGES = [
    "L_REFEED_LOAD_0",      # the loop back to the top: iteration i+1
    "L_RECORD_ENGINE_0",    # turn ends, into the Stop hook
    "L_PROMISE_ENGINE_0",   # the declaration, into the Stop hook
    "L_CHECKS_REPORT_0",    # every check holds - converged
    "L_RECORD_REPORT_0",    # needs your decision
    "L_CLEAN_RECORD_0",     # findings filed, most severe first
    "L_OPEN_EVAL_0",        # early evaluator gate
    "L_GATE_RECORD_0",      # verify green, back to record
]
MARKER = "my-svg_flowchart-v2-pointEnd"

THEMES = {
    "light": {"args": ["-b", "white"], "bg": "#FFFFFF", "out": "flowchart-light.png"},
    "dark": {"args": ["-t", "dark", "-b", "#0D1117"], "bg": "#0D1117", "out": "flowchart-dark.png"},
}


def render_svg(theme_args: list[str], out_svg: Path) -> str:
    cmd = ["npx", "-y", "@mermaid-js/mermaid-cli@11", "-i", str(MMD), "-o", str(out_svg), *theme_args]
    subprocess.run(cmd, check=True, shell=(sys.platform == "win32"))
    return out_svg.read_text(encoding="utf-8")


def inject_mid_markers(svg: str) -> str:
    for eid in LONG_EDGES:
        needle = f'id="{eid}"'
        if needle not in svg:
            raise SystemExit(f"edge id {eid} not found - the .mmd edges changed; update LONG_EDGES")
        svg = svg.replace(needle, f'{needle} marker-mid="url(#{MARKER})"', 1)
    return svg


def rasterize(svg: str, bg: str, out_png: Path) -> None:
    html = f'<!doctype html><body style="margin:0;background:{bg}">{svg}</body>'
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(device_scale_factor=3)
        page.set_content(html)
        page.wait_for_timeout(500)
        el = page.query_selector("svg")
        el.screenshot(path=str(out_png))
        browser.close()


def main() -> None:
    for name, cfg in THEMES.items():
        with tempfile.TemporaryDirectory() as td:
            svg_path = Path(td) / f"flowchart-{name}.svg"
            svg = render_svg(cfg["args"], svg_path)
        svg = inject_mid_markers(svg)
        out = ROOT / "media" / cfg["out"]
        rasterize(svg, cfg["bg"], out)
        print(f"{name}: {out} written")


if __name__ == "__main__":
    main()
