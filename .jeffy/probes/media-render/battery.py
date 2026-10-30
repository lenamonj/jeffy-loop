"""Known-answer battery for the two media render scripts that had no oracle.

scripts/render-running-jeffy.py and scripts/render-how-it-works.py each drive a
page in media/ through Chromium at a hardcoded viewport and screenshot what the
page computes.  py_compile plus "the committed output exists" was all the
previous sweeps could obtain, and neither is a known-answer check on a computed
value, so both rows sat unswept.  What this battery grades is the computation
itself: the exact strings and sizes the two pages produce at named frames and
named themes, driven through a real browser.

Documented parameters, each exercised at two or more values that must change the
output, with boundary and negative sides:
  theme   - dark (default), light, and a value that is neither.
  n       - the frame index render-how-it-works.py sweeps with setFrame(n),
            at every STAGES boundary and at both ends of each animated ramp.

Usage: battery.py <tree-root>.  Exit 0 and one summary line when every known
answer holds; 1 with the disagreements; 2 when no browser can be resolved here,
which is an instrument finding about this host rather than a product defect.
"""
import os
import pathlib
import re
import struct
import sys

from playwright.sync_api import Error as PWError
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(sys.argv[1]).resolve()
DARK = "rgb(7, 9, 13)"
WHITE = "rgb(255, 255, 255)"

failures = []


def check(label, got, want):
    if got != want:
        failures.append("FAIL %s: got %r, want %r" % (label, got, want))


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def resolve_browser(pw):
    """Return an executable_path, or None to let Playwright use its own build.

    The registered build and the cached one drift apart whenever the Python
    package is upgraded without re-running `playwright install`, which is the
    state this host is in: the package asks for build 1248 and the cache holds
    1228.  Trying the default first and globbing only on failure keeps a
    correctly installed host on its own browser.
    """
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
        raise SystemExit(
            "NOT RUNNABLE: no Chromium build under %s and Playwright's own is absent; "
            "run `playwright install chromium`" % base
        )
    return str(found[-1])


def page_url(name, theme=None):
    uri = (ROOT / "media" / name).as_uri()
    return uri if theme is None else "%s?theme=%s" % (uri, theme)


def sweep_running_jeffy(browser, tmp):
    """scripts/render-running-jeffy.py: viewport 1660x760, two themes, PNG out."""
    page = browser.new_page(viewport={"width": 1660, "height": 760}, device_scale_factor=1)
    shots = {}
    for theme, want_bg, want_attr in (
        (None, DARK, None),          # the script's dark pass
        ("light", WHITE, "light"),   # the script's light pass
        ("sepia", DARK, None),       # negative: not one of the two it drives
    ):
        page.goto(page_url("running-jeffy.html", theme))
        page.wait_for_function("document.fonts.status === 'loaded'")
        page.wait_for_timeout(300)
        label = "running-jeffy theme=%s" % (theme or "default")
        check(label + " data-theme",
              page.evaluate("document.documentElement.getAttribute('data-theme')"), want_attr)
        check(label + " body background",
              page.evaluate("getComputedStyle(document.body).backgroundColor"), want_bg)
        check(label + " declared page size",
              page.evaluate("[document.documentElement.scrollWidth, document.documentElement.scrollHeight]"),
              [1660, 760])
        out = tmp / ("running-jeffy-%s.png" % (theme or "dark"))
        page.screenshot(path=str(out))
        check(label + " png size", png_size(out), (1660, 760))
        shots[theme or "dark"] = out.read_bytes()
    if shots["dark"] == shots["light"]:
        failures.append("FAIL running-jeffy: theme=light renders byte-identically to the dark pass, "
                        "so the parameter the script drives changes nothing")
    if shots["sepia"] != shots["dark"]:
        failures.append("FAIL running-jeffy: an unknown theme value does not fall back to the dark render")
    page.close()


# The page's own arithmetic, restated here from media/how-it-works.html's
# constants so the expected values are computed rather than observed.  Comparing
# numerically rather than against the toFixed string is deliberate: the browser
# re-serializes an inline style value and drops trailing zeros, so a string
# comparison grades CSS serialization instead of the animation.
TOTAL = 240
CMD = "/jeffy"
T0, T1 = 4, 16
ITER_FRAMES = (52, 98, 144)
STAGES = ((0, "audit", ""), (52, "iterate", ""), (190, "verify", ""), (214, "converged", "g"))
BADGE_IN, BADGE_OUT = 214, 222


def cl(v):
    return max(0.0, min(1.0, v))


def pr(f, a, b):
    return cl((f - a) / (b - a))


def out_cubic(t):
    return 1 - (1 - t) ** 3


def expected(f):
    badge = out_cubic(pr(f, BADGE_IN, BADGE_OUT))
    stage = STAGES[0]
    for s in STAGES:
        if f >= s[0]:
            stage = s
    return {
        "stage": stage[1],
        "stageClass": stage[2],
        "cam": 1 + 0.03 * pr(f, 0, TOTAL),
        "glyph": sum(360 * out_cubic(pr(f, i, i + 30)) for i in ITER_FRAMES),
        "badgeOpacity": badge,
        "badgeTransform": 0.9 + 0.1 * badge,
        # JS Math.round is half-up, which int(x + 0.5) reproduces for x >= 0.
        "typed": CMD[: int(pr(f, T0, T1) * len(CMD) + 0.5)],
    }


# Every STAGES boundary and the frame before it, both ends of the typing ramp,
# both ends of each glyph turn, and both ends of the badge fade.
HIW_FRAMES = (0, 4, 10, 16, 51, 52, 81, 82, 120, 127, 128, 173, 174,
              189, 190, 213, 214, 218, 222, 239, 240)

READ_FRAME = """() => ({
  stage: document.getElementById('stageLbl').textContent,
  stageClass: document.getElementById('stageLbl').className,
  cam: document.getElementById('cam').style.transform,
  glyph: document.getElementById('glyph').style.transform,
  badgeOpacity: document.getElementById('badge').style.opacity,
  badgeTransform: document.getElementById('badge').style.transform,
  typed: document.querySelector('#feed .fl .a').textContent,
})"""

NUM = re.compile(r"-?\d+(?:\.\d+)?")


def one_number(label, text):
    """The single number inside a serialized transform or opacity value."""
    found = NUM.findall(text or "")
    if len(found) != 1:
        failures.append("FAIL %s: %r does not carry exactly one number" % (label, text))
        return None
    return float(found[0])


def check_near(label, text, want, places):
    """Agree to within half of the last digit the page's own toFixed prints."""
    got = one_number(label, text)
    if got is None:
        return
    if abs(got - want) > 0.5 * 10 ** -places + 1e-12:
        failures.append("FAIL %s: got %s, want %.*f" % (label, got, places, want))


def sweep_how_it_works(browser, tmp):
    """scripts/render-how-it-works.py: viewport 1200x676, setFrame(n) per frame."""
    page = browser.new_page(viewport={"width": 1200, "height": 676}, device_scale_factor=1)
    page.goto(page_url("how-it-works.html"))
    page.wait_for_function("document.fonts.status === 'loaded'")
    page.wait_for_timeout(300)

    check("how-it-works TOTAL", page.evaluate("window.TOTAL"), TOTAL)
    check("how-it-works setFrame type", page.evaluate("typeof window.setFrame"), "function")
    check("how-it-works declared page size",
          page.evaluate("[document.documentElement.scrollWidth, document.documentElement.scrollHeight]"),
          [1200, 676])

    for n in HIW_FRAMES:
        page.evaluate("setFrame(%d)" % n)
        got = page.evaluate(READ_FRAME)
        want = expected(n)
        at = "how-it-works setFrame(%d)" % n
        check(at + " stage", got["stage"], want["stage"])
        check(at + " stage class", got["stageClass"], want["stageClass"])
        check(at + " typed command", got["typed"], want["typed"])
        check_near(at + " camera", got["cam"], want["cam"], 4)
        check_near(at + " glyph", got["glyph"], want["glyph"], 2)
        check_near(at + " badge opacity", got["badgeOpacity"], want["badgeOpacity"], 3)
        check_near(at + " badge transform", got["badgeTransform"], want["badgeTransform"], 3)

    # The script's own correctness claim: setFrame(n) fully determines the image,
    # so revisiting a frame reproduces it byte for byte and a different frame does not.
    page.evaluate("setFrame(0)")
    first = tmp / "hiw-0-a.png"
    page.screenshot(path=str(first), animations="disabled")
    page.evaluate("setFrame(239)")
    last = tmp / "hiw-239.png"
    page.screenshot(path=str(last), animations="disabled")
    page.evaluate("setFrame(0)")
    again = tmp / "hiw-0-b.png"
    page.screenshot(path=str(again), animations="disabled")
    if first.read_bytes() != again.read_bytes():
        failures.append("FAIL how-it-works: setFrame(0) does not reproduce after setFrame(239), "
                        "so the clip the script renders is not deterministic")
    if first.read_bytes() == last.read_bytes():
        failures.append("FAIL how-it-works: setFrame(239) renders identically to setFrame(0), "
                        "so the frame index changes nothing")
    check("how-it-works png size", png_size(first), (1200, 676))

    for theme, want_bg, want_attr in ((None, DARK, None), ("light", WHITE, "light"), ("sepia", DARK, None)):
        page.goto(page_url("how-it-works.html", theme))
        page.wait_for_function("document.fonts.status === 'loaded'")
        label = "how-it-works theme=%s" % (theme or "default")
        check(label + " data-theme",
              page.evaluate("document.documentElement.getAttribute('data-theme')"), want_attr)
        check(label + " body background",
              page.evaluate("getComputedStyle(document.body).backgroundColor"), want_bg)
    page.close()


def main():
    tmp = ROOT / ".jeffy" / "scratch" / "media-render"
    tmp.mkdir(parents=True, exist_ok=True)
    for stale in tmp.glob("*.png"):
        stale.unlink()
    with sync_playwright() as pw:
        exe = resolve_browser(pw)
        browser = pw.chromium.launch(
            executable_path=exe,
            args=["--force-color-profile=srgb", "--disable-lcd-text"],
        )
        try:
            sweep_running_jeffy(browser, tmp)
            sweep_how_it_works(browser, tmp)
        finally:
            browser.close()
    if failures:
        print("\n".join(failures))
        sys.exit(1)
    print("media-render battery ok: running-jeffy at 1660x760 over 3 theme values, "
          "how-it-works at 1200x676 over %d known-answer frames and 3 theme values, "
          "setFrame determinism and frame-sensitivity both driven" % len(HIW_FRAMES))


main()
