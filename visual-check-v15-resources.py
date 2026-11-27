"""Visual check for resources (Phase 15): a village ringed by mountains
hires miners, the miners haul stone/iron into the store, the era
advances on what was mined, and the houses redraw in the era's style.
Saves visual-check-v15-resources-{fit,zoomed}.png.

Coordinates (720x1280): Grass (80, 1118); Forest (346, 1118); Mountain
(480, 1118); Person (613, 1118); Speed (540, 32); zoom (680, 98);
Fit (680, 165); map centre (360, 640).
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
    page.goto(BASE + "/index.html?v=resources", wait_until="load", timeout=60000)
    page.wait_for_timeout(10000)
    # Forest around the centre (food), then a mountain range just
    # right of it (the miners' quarry — inside the village's reach).
    page.mouse.click(346, 1118)
    page.wait_for_timeout(500)
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            page.mouse.click(360 + dx * 11, 640 + dy * 11)
            page.wait_for_timeout(60)
    page.mouse.click(480, 1118)
    page.wait_for_timeout(500)
    for dy in range(-2, 3):
        for dx in range(2, 10):
            page.mouse.click(360 + dx * 11, 640 + dy * 11)
            page.wait_for_timeout(60)
    # 24 people in one tight cluster, fast (100ms gaps) — they found
    # a village, and the mountains hire miners.
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for i in range(24):
        page.mouse.click(360 + (i % 6) * 10 - 25, 640 + (i // 6) * 10 - 15)
        page.wait_for_timeout(100)
    # 4x is two clicks from 1x (the button cycles 1x -> 2x -> 4x).
    page.mouse.click(540, 32)
    page.wait_for_timeout(300)
    page.mouse.click(540, 32)
    page.wait_for_timeout(500)
    # ~420s at 4x (to ~Day 18): the spawned children grow up on Day 13
    # and take jobs — the miners work a mountain every day, the store
    # fills with stone/iron, and the era (and the houses) advance on
    # what was mined.
    page.wait_for_timeout(420000)
    page.screenshot(path=f"{OUT}/visual-check-v15-resources-fit.png")
    page.mouse.click(680, 98)  # zoom in on the village
    page.wait_for_timeout(2000)
    page.screenshot(path=f"{OUT}/visual-check-v15-resources-zoomed.png")
    errors = [c for c in console if c.startswith("error") or "Error" in c]
    print("console errors:", errors)
    print("failed requests:", failed)
    browser.close()
print("done")
