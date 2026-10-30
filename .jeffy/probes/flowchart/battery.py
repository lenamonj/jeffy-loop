"""Known-answer battery for scripts/render-flowchart.py.

The script renders media/flowchart.mmd with mermaid-cli and then rewrites the
SVG in the browser: REROUTE_JS replaces five edges dagre draws badly, and
RESAMPLE_JS hangs an invisible companion polyline off every long edge so
chevrons trace it at even intervals.  Both halves address the live mermaid DOM
by id, and both degrade silently when that DOM moves - REROUTE_JS pushes
`<edge>:MISSING` onto a list the script only prints, and a marker id that no
longer resolves leaves every chevron referencing nothing and drawing nothing.
py_compile and "the committed PNGs exist" could not see any of that, which is
why this row sat unswept.

What is graded, all of it against the shipped module's own constants rather
than a copy of them:
  - the two marker ids the script hardcodes resolve in the SVG mermaid really
    produces, with a deliberately wrong id as the negative control;
  - every node media/flowchart.mmd declares resolves in the SVG through the
    very selector REROUTE_JS addresses nodes by, so a node renamed in the
    source cannot leave a route silently anchorless;
  - all five manual routes resolve, none reporting MISSING;
  - the amber edges in the SVG are exactly the dotted state-plane edges the
    .-> declarations in media/flowchart.mmd name, which is what breaks when an
    edge is added above the indices linkStyle addresses them by.  The mmd's own
    comment flags that hazard and nothing checked it; comparing counts cannot
    see it, because a shift moves the colour without changing how much of it
    there is.
  - SPACING, the one documented parameter, at three values that must change the
    chevron count, including the zero the script treats as fatal;
  - the theme parameter at both of its values, which must change the SVG.

Usage: battery.py <tree-root>.  Exit 0 and one summary line when every known
answer holds, 1 with the disagreements, 2 when no browser can be resolved.
"""
import importlib.util
import os
import pathlib
import re
import sys

from playwright.sync_api import Error as PWError
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(sys.argv[1]).resolve()
failures = []


def check(label, got, want):
    if got != want:
        failures.append("FAIL %s: got %r, want %r" % (label, got, want))


def load_script():
    path = ROOT / "scripts" / "render-flowchart.py"
    spec = importlib.util.spec_from_file_location("render_flowchart_under_test", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def resolve_browser(pw):
    """Return an executable_path, or None to let Playwright use its own build."""
    try:
        pw.chromium.launch().close()
        return None
    except PWError:
        pass
    base = os.environ.get("PLAYWRIGHT_BROWSERS_PATH")
    base = pathlib.Path(base) if base else pathlib.Path.home() / ".cache" / "ms-playwright"
    patterns = (
        "chromium-*/chrome-linux64/chrome",
        "chromium-*/chrome-linux/chrome",
        "chromium-*/chrome-mac/Chromium.app/Contents/MacOS/Chromium",
        "chromium-*/chrome-win/chrome.exe",
    )
    found = sorted(c for pat in patterns for c in base.glob(pat) if c.exists())
    if not found:
        raise SystemExit("NOT RUNNABLE: no Chromium build under %s and Playwright's own is absent" % base)
    return str(found[-1])


def amber_contract():
    """What media/flowchart.mmd asks for: how many edges linkStyle colours, and
    how many dotted edges it declares.  The directive addresses edges by
    declaration index and the comment beside it says an edge added earlier
    shifts them, so the contract the render must satisfy is that the two sets
    coincide - the amber edges are the dotted ones - and not merely that four
    edges came out amber."""
    mmd = (ROOT / "media" / "flowchart.mmd").read_text(encoding="utf-8")
    m = re.search(r"^\s*linkStyle\s+([0-9,\s]+?)\s+stroke:#CA8A04", mmd, re.M)
    if not m:
        raise SystemExit("NOT RUNNABLE: media/flowchart.mmd declares no amber linkStyle for this battery to derive from")
    styled = len([tok for tok in m.group(1).split(",") if tok.strip()])
    dotted = len(re.findall(r"\.->", mmd))
    if styled != dotted:
        raise SystemExit("NOT RUNNABLE: flowchart.mmd colours %d edges but declares %d dotted ones, so the "
                         "contract this battery compares is not stated by the source" % (styled, dotted))
    return styled


NODE_DECL = re.compile(r"^\s*([A-Z][A-Z0-9_]*)\s*[\[({]", re.M)


def nodes_declared():
    """The node ids media/flowchart.mmd declares, in the form REROUTE_JS looks
    them up by.  Subgraph names open with the `subgraph` keyword and are not
    nodes, so the keyword lines are dropped before matching."""
    mmd = (ROOT / "media" / "flowchart.mmd").read_text(encoding="utf-8")
    body = "\n".join(ln for ln in mmd.splitlines()
                     if not ln.lstrip().startswith(("subgraph", "%%", "classDef", "style", "linkStyle")))
    found = sorted(set(NODE_DECL.findall(body)))
    if not found:
        raise SystemExit("NOT RUNNABLE: no node declarations matched in media/flowchart.mmd")
    return found


RESOLVE_NODES = """(names) => names.filter(
  n => !document.querySelector('g[id*="flowchart-' + n + '-"]'))"""


def respaced(js, spacing):
    out, n = re.subn(r"const SPACING = \d+;", "const SPACING = %d;" % spacing, js)
    if n != 1:
        raise SystemExit("NOT RUNNABLE: RESAMPLE_JS no longer carries exactly one SPACING literal")
    return out


EDGE_CLASSES = """() => [...document.querySelectorAll('path.flowchart-link')].map(p => ({
  id: p.getAttribute('data-id') || p.id,
  cls: p.getAttribute('class') || '',
  style: p.getAttribute('style') || '',
}))"""

COUNT_MARKERS = """(marker) => document.querySelectorAll(
  'path[marker-end="url(#' + marker + ')"]').length"""


def main():
    mod = load_script()
    tmp = ROOT / ".jeffy" / "scratch" / "flowchart"
    tmp.mkdir(parents=True, exist_ok=True)

    svgs = {}
    for name, cfg in mod.THEMES.items():
        svgs[name] = mod.render_svg(cfg["args"], tmp / ("flowchart-%s.svg" % name))

    if svgs["light"] == svgs["dark"]:
        failures.append("FAIL theme: the dark and light renders are identical, "
                        "so the theme arguments the script passes change nothing")

    want_amber = amber_contract()
    want_nodes = nodes_declared()

    with sync_playwright() as pw:
        exe = resolve_browser(pw)
        browser = pw.chromium.launch(executable_path=exe)
        try:
            for name, cfg in mod.THEMES.items():
                svg = svgs[name]
                for label, marker in (("point", mod.MARKER), ("amber", mod.AMBER_MARKER)):
                    check("%s svg carries the %s marker id %s" % (name, label, marker),
                          ('id="%s"' % marker) in svg, True)
                check("%s svg does not carry a marker id the script never names" % name,
                      ('id="%s-no-such-marker"' % mod.MARKER) in svg, False)

                page = browser.new_page(device_scale_factor=1)
                page.set_content('<!doctype html><body style="margin:0;background:%s">%s</body>'
                                 % (cfg["bg"], svg))
                page.wait_for_timeout(500)

                check("%s svg resolves every node flowchart.mmd declares" % name,
                      page.evaluate(RESOLVE_NODES, want_nodes), [])
                check("%s node lookup rejects a name the source never declares" % name,
                      page.evaluate(RESOLVE_NODES, ["NOSUCHNODE"]), ["NOSUCHNODE"])

                routes = page.evaluate(mod.REROUTE_JS).split()
                check("%s reroute resolves every manual route" % name,
                      sorted(r for r in routes if not r.endswith(":ok")), [])
                check("%s reroute route count" % name, len(routes), 5)

                edges = page.evaluate(EDGE_CLASSES)
                amber = sorted(e["id"] for e in edges if "CA8A04" in e["style"])
                dotted = sorted(e["id"] for e in edges if "edge-pattern-dotted" in e["cls"])
                check("%s amber edges are the dotted state-plane edges" % name, amber, dotted)
                check("%s amber edge count against flowchart.mmd" % name, len(amber), want_amber)

                # SPACING at three values. The script treats 0 added as fatal, so the
                # wide value drives its own failure branch from the outside.
                added = page.evaluate(respaced(mod.RESAMPLE_JS, mod.SPACING))
                if added <= 0:
                    failures.append("FAIL %s resample at SPACING=%d added no chevrons, which is the "
                                    "SVG-shape change the script aborts on" % (name, mod.SPACING))
                tighter = page.evaluate(respaced(mod.RESAMPLE_JS, mod.SPACING // 2))
                if tighter <= added:
                    failures.append("FAIL %s resample: halving SPACING added %d chevrons against %d at "
                                    "%d, so the parameter does not tighten the spacing"
                                    % (name, tighter, added, mod.SPACING))
                check("%s resample at a SPACING longer than every edge" % name,
                      page.evaluate(respaced(mod.RESAMPLE_JS, 1000000)), 0)

                point_chevrons = page.evaluate(COUNT_MARKERS, mod.MARKER)
                amber_chevrons = page.evaluate(COUNT_MARKERS, mod.AMBER_MARKER)
                if amber_chevrons == 0:
                    failures.append("FAIL %s: no chevron companion references the amber marker, so the "
                                    "amber branch of RESAMPLE_JS is dead against this SVG" % name)
                if point_chevrons == 0:
                    failures.append("FAIL %s: no chevron companion references the point marker" % name)
                page.close()
        finally:
            browser.close()

    if failures:
        print("\n".join(failures))
        sys.exit(1)
    print("flowchart battery ok: both themes rendered through mermaid-cli, 5/5 manual routes resolved, "
          "the %d amber edges are exactly the dotted ones flowchart.mmd declares, all %d declared nodes "
          "resolved, both marker ids live, SPACING driven at three values" % (want_amber, len(want_nodes)))


main()
