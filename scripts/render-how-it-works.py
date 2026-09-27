"""Render media/how-it-works.html to media/how-it-works.gif (and .mp4).

1200x676 CSS px at 15 fps; every frame is set with setFrame(n) so the clip is
deterministic. The gif goes through a two-pass palette so the dark stage does
not band. Requires playwright (chromium) and imageio_ffmpeg.
"""
import pathlib
import subprocess
import tempfile

import imageio_ffmpeg
from playwright.sync_api import sync_playwright

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "media" / "how-it-works.html").as_uri()
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
FPS = 15

with tempfile.TemporaryDirectory() as tmp:
    frames = pathlib.Path(tmp)
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--force-color-profile=srgb", "--disable-lcd-text"])
        page = browser.new_page(viewport={"width": 1200, "height": 676}, device_scale_factor=1)
        page.goto(src)
        page.wait_for_function("document.fonts.status === 'loaded'")
        page.wait_for_timeout(300)
        total = page.evaluate("window.TOTAL")
        for f in range(total):
            page.evaluate(f"setFrame({f})")
            page.screenshot(path=str(frames / f"{f:05d}.png"), animations="disabled")
        browser.close()
    seq = str(frames / "%05d.png")
    gif = root / "media" / "how-it-works.gif"
    mp4 = root / "media" / "how-it-works.mp4"
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", seq,
                    "-vf", "split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle",
                    "-loop", "0", str(gif)], check=True)
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", seq,
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", str(mp4)], check=True)
    print(f"wrote {gif} ({gif.stat().st_size // 1024} KB) and {mp4} ({mp4.stat().st_size // 1024} KB)")
