"""Render media/running-jeffy.html to media/running-jeffy.png (1660x760, shown at 830 in the README)."""
import pathlib
from playwright.sync_api import sync_playwright

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "media" / "running-jeffy.html").as_uri()
out = root / "media" / "running-jeffy.png"
with sync_playwright() as p:
    browser = p.chromium.launch(args=["--force-color-profile=srgb", "--disable-lcd-text"])
    page = browser.new_page(viewport={"width": 1660, "height": 760}, device_scale_factor=1)
    page.goto(src)
    page.wait_for_function("document.fonts.status === 'loaded'")
    page.wait_for_timeout(300)
    page.screenshot(path=str(out))
    browser.close()
print(f"wrote {out} ({out.stat().st_size // 1024} KB)")
