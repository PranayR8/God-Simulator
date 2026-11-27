"""Visual check for gear & inspect (Phase 16): a village grows up, its
people are equipped in the era's material, and tapping a villager
with the Inspect tool opens their panel (stats, items, heritage)
with a white ring on the selected person.
Saves visual-check-v16-gear-{toolbar,inspect}.png.

Coordinates (720x1280): Grass (80, 1118); Forest (346, 1118); Person
(613, 1118); Inspect (613, 1238, row 3 col 5); Speed (540, 32);
zoom (680, 98); Fit (680, 165); map centre (360, 640).
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
    page.goto(BASE + "/index.html?v=gear", wait_until="load", timeout=60000)
    page.wait_for_timeout(10000)
    # Forest around the centre (food), then 24 people in one tight
    # cluster, fast (100ms gaps) — they found a village.
    page.mouse.click(346, 1118)
    page.wait_for_timeout(500)
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            page.mouse.click(360 + dx * 11, 640 + dy * 11)
            page.wait_for_timeout(60)
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
    # ~420s at 4x (to ~Day 13): the children grow up and are equipped
    # in the era's material.
    page.wait_for_timeout(420000)
    # Select the Inspect tool (row 3, 5th button) and tap a few spots
    # around the village centre — the villagers wander, so one of
    # these should land on a person and open their panel.
    page.mouse.click(613, 1238)
    page.wait_for_timeout(800)
    page.screenshot(path=f"{OUT}/visual-check-v16-gear-toolbar.png")
    for pos in [(360, 640), (350, 650), (370, 630), (355, 645), (365, 655)]:
        page.mouse.click(pos[0], pos[1])
        page.wait_for_timeout(1200)
    page.screenshot(path=f"{OUT}/visual-check-v16-gear-inspect.png")
    errors = [c for c in console if c.startswith("error") or "Error" in c]
    print("console errors:", errors)
    print("failed requests:", failed)
    browser.close()
print("done")
