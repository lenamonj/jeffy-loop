"""Render media/banner.html to media/banner-{light,dark}.png at 2x scale."""
import pathlib
from playwright.sync_api import sync_playwright

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "media" / "banner.html").as_uri()

with sync_playwright() as p:
    browser = p.chromium.launch()
    for theme in ("light", "dark"):
        page = browser.new_page(viewport={"width": 1600, "height": 380}, device_scale_factor=2)
        page.goto(f"{src}?theme={theme}")
        page.wait_for_timeout(300)
        out = root / "media" / f"banner-{theme}.png"
        page.screenshot(path=str(out))
        print(f"wrote {out}")
        page.close()
    browser.close()
