"""Visual check for kingdoms & diplomacy (Phase 17): two Towns near
each other form a kingdom — the capital wears a gold crown, the
territory borders take the kingdom's colour, and a member village's
label names its kingdom. The History logs the founding.
Saves visual-check-v17-kingdoms-{fit,zoomed,log}.png.

Coordinates (720x1280): Grass (80, 1118); Forest (346, 1118); Person
(613, 1118); Speed (540, 32); log toggle (268, 98); zoom (680, 98);
Fit (680, 165); map centre (360, 640). Cluster B is ~10 tiles east
of the centre (~115 screen px at fit zoom).
"""
import urllib.request
from playwright.sync_api import sync_playwright

BASE = "http://localhost:8931"
OUT = "/home/hatch/workspace/god-simulator-checks"

def pck_info():
    req = urllib.request.Request(BASE + "/index.pck", method="HEAD")
    with urllib.request.urlopen(req, timeout=10) as r:
        return {"status": r.status, "size": r.headers.get("Content-Length")}

print("pck:", pck_info())

with sync_playwright() as p:
    browser = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    page = browser.new_page(viewport={"width": 720, "height": 1280})
    console = []
    failed = []
    page.on("console", lambda m: console.append(f"{m.type}: {m.text}"))
    page.on("requestfailed", lambda r: failed.append(r.url))
    page.goto(BASE + "/index.html?v=kingdoms", wait_until="load", timeout=60000)
    page.wait_for_timeout(10000)
    # Forest around both cluster centres (food, so nobody starves and
    # no one rebels while the kingdom forms).
    page.mouse.click(346, 1118)
    page.wait_for_timeout(500)
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            page.mouse.click(360 + dx * 11, 640 + dy * 11)
            page.wait_for_timeout(40)
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            page.mouse.click(475 + dx * 11, 640 + dy * 11)
            page.wait_for_timeout(40)
    # 35 people in cluster A (the centre) and 32 in cluster B, fast
    # (100ms gaps) — each cluster founds a village, and with 30+
    # people each is a Town at once, so a kingdom forms.
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for i in range(35):
        page.mouse.click(360 + (i % 7) * 9 - 27, 640 + (i // 7) * 9 - 18)
        page.wait_for_timeout(100)
    for i in range(32):
        page.mouse.click(475 + (i % 7) * 9 - 27, 640 + (i // 7) * 9 - 18)
        page.wait_for_timeout(100)
    # 4x is two clicks from 1x (the button cycles 1x -> 2x -> 4x).
    page.mouse.click(540, 32)
    page.wait_for_timeout(300)
    page.mouse.click(540, 32)
    page.wait_for_timeout(500)
    # ~90s at 4x: the villages form, reach Town, and the kingdom
    # forms (kingdom founding runs on the day tick).
    page.wait_for_timeout(90000)
    page.screenshot(path=f"{OUT}/visual-check-v17-kingdoms-fit.png")
    # Zoom in on the two villages for the crown and the border colour.
    page.mouse.click(680, 98)
    page.wait_for_timeout(1500)
    page.screenshot(path=f"{OUT}/visual-check-v17-kingdoms-zoomed.png")
    # Open the History log to see the kingdom founding line.
    page.mouse.click(268, 98)
    page.wait_for_timeout(1500)
    page.screenshot(path=f"{OUT}/visual-check-v17-kingdoms-log.png")
    errors = [c for c in console if c.startswith("error") or "Error" in c]
    print("console errors:", errors)
    print("failed requests:", failed)
    browser.close()
print("done")
