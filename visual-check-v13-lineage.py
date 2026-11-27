"""Visual check for a family line (Phase 12): spawn a village and confirm
the History names a house and a generation — "House of X, 2nd generation"
— when the first child of the next generation is born. Also confirms a
founder hero (the village's first citizen) carries a gold ring.
Saves visual-check-v13-lineage-{fit,zoomed,log}.png.

Coordinates (720x1280): Forest (346, 1118); Person (613, 1118);
log toggle (268, 98); zoom (680, 98); speed (540, 32); Fit (680, 165);
map centre (360, 640).
"""
import json, urllib.request
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
    page.goto(BASE + "/index.html?v=lineage", wait_until="load", timeout=60000)
    page.wait_for_timeout(10000)
    # Forest around the centre, so the village has food and survives.
    page.mouse.click(346, 1118)
    page.wait_for_timeout(500)
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            page.mouse.click(360 + dx * 11, 640 + dy * 11)
            page.wait_for_timeout(60)
    # 14 people in one cluster, fast (100ms gaps) — they found a village.
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for i in range(14):
        page.mouse.click(360 + (i % 5) * 12 - 24, 640 + (i // 5) * 12 - 24)
        page.wait_for_timeout(100)
    # Let the village form (15s at 1x), then 4x so births come fast.
    page.wait_for_timeout(15000)
    page.mouse.click(540, 32)
    page.wait_for_timeout(300)
    page.mouse.click(540, 32)
    page.wait_for_timeout(300)
    # ~400s at 4x (to ~Day 15): the spawned children grow up at Day 13
    # (they are children for 12 days) and start having children of
    # their own. The first child of the next generation writes the
    # "House of X, 2nd generation" line into the History. (The world
    # also starts with 10 scattered nomads, so People is 24, not 14.)
    page.wait_for_timeout(400000)
    # Fit shot, then zoomed, then the log.
    page.screenshot(path=f"{OUT}/visual-check-v13-lineage-fit.png")
    for _ in range(3):
        page.mouse.click(680, 98)
        page.wait_for_timeout(500)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v13-lineage-zoomed.png")
    page.mouse.click(268, 98)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v13-lineage-log.png")
    page.mouse.click(680, 165)
    page.wait_for_timeout(500)
    errors = [c for c in console if c.startswith("error") or "Error" in c]
    print("console errors:", errors)
    print("failed requests:", failed)
    browser.close()
print("done")
