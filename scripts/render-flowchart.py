"""Render media/flowchart.mmd to the two README PNGs, with directional
arrowheads repeated along every edge.

Why this script exists: mermaid draws one arrowhead per edge, at the far
end, so on long sweeps the direction of flow is invisible. SVG marker-mid
repeats arrowheads, but only at path vertices - and dagre emits long
straight runs with no interior vertices, so attribute injection alone
leaves them bare (and Chromium ignores marker-mid as CSS entirely). This
script renders the SVGs with mmdc, then rasterizes with Playwright after
resampling each edge in the browser: an invisible companion polyline with
a vertex every SPACING px carries the markers, so chevrons trace the true
curve at even intervals whatever shape dagre drew.

Usage: python scripts/render-flowchart.py  (from the repo root)
"""

import subprocess
import sys
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
MMD = ROOT / "media" / "flowchart.mmd"

MARKER = "my-svg_flowchart-v2-pointEnd"
AMBER_MARKER = "my-svg_flowchart-v2-pointEnd__CA8A04"
SPACING = 220  # px of path length between chevrons; edges shorter than
               # 1.5x this keep only their endpoint arrow

# Manual routes for edges dagre draws badly: REVERT's page-wide left
# detour under the evaluator diamond becomes the short drop into RECORD,
# and the PROM/CHECKS pair into BUDGET uncrosses - the "no" drop takes
# the diamond's top vertex, the check-failed return takes its right
# vertex, its label moved to the new midpoint. Anchors are fractions of
# the live node boxes, so a layout shift cannot strand a route. Runs
# before the resampler so the chevrons follow the new curves.
REROUTE_JS = """
() => {
  const svg = document.querySelector('svg');
  const scale = svg.viewBox.baseVal.width / svg.getBoundingClientRect().width;
  const box = el => { const r = el.getBoundingClientRect(), s = svg.getBoundingClientRect();
    return { x: (r.x - s.x) * scale, y: (r.y - s.y) * scale, w: r.width * scale, h: r.height * scale }; };
  const node = name => document.querySelector('g[id*="flowchart-' + name + '-"]');
  const anchor = (n, fx, fy) => { const b = box(node(n)); return { x: b.x + b.w * fx, y: b.y + b.h * fy }; };
  const ROUTES = [
    { edge: 'L_REVERT_RECORD_0', from: ['REVERT', 0.5, 1], to: ['RECORD', 0.8, 0], label: false },
    { edge: 'L_PROM_BUDGET_0', from: ['PROM', 0.5, 1], to: ['BUDGET', 0.5, 0], label: false },
    { edge: 'L_CHECKS_BUDGET_0', from: ['CHECKS', 0, 0.5], to: ['BUDGET', 0.75, 0.25], label: true, trim: 0 },
  ];
  const done = [];
  for (const r of ROUTES) {
    const path = document.querySelector('path[data-id="' + r.edge + '"], path[id*="' + r.edge + '"]');
    if (!path || !node(r.from[0]) || !node(r.to[0])) { done.push(r.edge + ':MISSING'); continue; }
    const s = anchor(...r.from), e = anchor(...r.to);
    e.y -= (r.trim === undefined ? 4 : r.trim) * Math.sign(e.y - s.y) || 0;
    path.setAttribute('d', `M${s.x},${s.y} C${s.x + (e.x - s.x) * 0.15},${s.y + (e.y - s.y) * 0.55} ${e.x + (s.x - e.x) * 0.15},${e.y - (e.y - s.y) * 0.35} ${e.x},${e.y}`);
    if (r.label) {
      const inner = document.querySelector('g[data-id="' + r.edge + '"]');
      const lab = inner ? inner.closest('.edgeLabel') : null;
      if (lab) {
        const m = path.getPointAtLength(path.getTotalLength() * 0.5);
        const pt = svg.createSVGPoint();
        pt.x = m.x; pt.y = m.y;
        const local = pt.matrixTransform(path.getCTM()).matrixTransform(lab.parentNode.getCTM().inverse());
        lab.setAttribute('transform', `translate(${local.x}, ${local.y})`);
      }
    }
    done.push(r.edge + ':ok');
  }
  return done.join(' ');
}
"""

RESAMPLE_JS = """
() => {
  const SPACING = %d;
  let added = 0;
  const edges = new Set(document.querySelectorAll(
    'path[id^="L_"], path[id*="-L_"], path[data-id^="L_"]'));
  edges.forEach(p => {
    const len = p.getTotalLength();
    if (len < SPACING * 1.5) return;
    const amber = (p.getAttribute('style') || '').includes('CA8A04');
    const marker = amber ? '%s' : '%s';
    const sw = getComputedStyle(p).strokeWidth || '2px';
    for (let d = SPACING * 0.6; d <= len - SPACING * 0.4; d += SPACING) {
      const a = p.getPointAtLength(Math.max(0, d - 8)), b = p.getPointAtLength(d);
      const c = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      c.setAttribute('d', `M${a.x.toFixed(2)},${a.y.toFixed(2)}L${b.x.toFixed(2)},${b.y.toFixed(2)}`);
      c.setAttribute('fill', 'none');
      c.setAttribute('stroke', amber ? '#CA8A04' : '#64748B');
      c.setAttribute('stroke-opacity', '0');
      c.setAttribute('stroke-width', sw);
      c.setAttribute('marker-end', 'url(#' + marker + ')');
      p.after(c);
      added++;
    }
  });
  return added;
}
""" % (SPACING, AMBER_MARKER, MARKER)

THEMES = {
    "light": {"args": ["-b", "white"], "bg": "#FFFFFF", "out": "flowchart-light.png"},
    "dark": {"args": ["-t", "dark", "-b", "#0D1117"], "bg": "#0D1117", "out": "flowchart-dark.png"},
}


def render_svg(theme_args: list[str], out_svg: Path) -> str:
    cmd = ["npx", "-y", "@mermaid-js/mermaid-cli@11", "-i", str(MMD), "-o", str(out_svg), *theme_args]
    subprocess.run(cmd, check=True, shell=(sys.platform == "win32"))
    return out_svg.read_text(encoding="utf-8")


def rasterize(svg: str, bg: str, out_png: Path) -> None:
    html = f'<!doctype html><body style="margin:0;background:{bg}">{svg}</body>'
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(device_scale_factor=3)
        page.set_content(html)
        page.wait_for_timeout(500)
        print(f"  {page.evaluate(REROUTE_JS)}")
        added = page.evaluate(RESAMPLE_JS)
        if added == 0:
            raise SystemExit("no edges resampled - the SVG shape changed; fix RESAMPLE_JS")
        print(f"  chevron companions added on {added} edges")
        page.wait_for_timeout(200)
        el = page.query_selector("svg")
        el.screenshot(path=str(out_png))
        browser.close()


def main() -> None:
    for name, cfg in THEMES.items():
        with tempfile.TemporaryDirectory() as td:
            svg_path = Path(td) / f"flowchart-{name}.svg"
            svg = render_svg(cfg["args"], svg_path)
        out = ROOT / "media" / cfg["out"]
        rasterize(svg, cfg["bg"], out)
        print(f"{name}: {out} written")


if __name__ == "__main__":
    main()
