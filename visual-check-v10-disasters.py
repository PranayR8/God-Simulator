"""Visual check for Phase 9 (Disasters): spawn 30 people in a village,
run at 4x to ~day 13, then unleash the Disaster button on the village
(a random disaster — plague, drought, or wildfire) and screenshot the
result, the zoomed view, and the History. Run it again after a reload
to see a different disaster (the button recharges on a fresh load).
Saves visual-check-v10-disasters-{fit,zoomed,log,crop}.png.

Coordinates (720x1280): Person tool (613, 1118); Disaster (478, 1238);
speed (540, 32) x2; log toggle (268, 98); zoom (680, 98);
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

with sync_playwright() as p:
    browser = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    page = browser.new_page(viewport={"width": 720, "height": 1280})
    console = []
    failed = []
    page.on("console", lambda m: console.append(f"{m.type}: {m.text}"))
    page.on("requestfailed", lambda r: failed.append(r.url))
    page.goto(BASE + "/index.html", wait_until="load", timeout=60000)
    page.wait_for_timeout(10000)
    # 30 people, fast (100 ms gaps), in a forest clearing near the centre.
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for i in range(30):
        page.mouse.click(360 + (i % 6) * 15 - 37, 640 + (i // 6) * 15 - 30)
        page.wait_for_timeout(100)
    # 4x speed: two clicks on the Speed button (1x -> 2x -> 4x).
    page.mouse.click(540, 32)
    page.wait_for_timeout(300)
    page.mouse.click(540, 32)
    page.wait_for_timeout(240000)  # ~13 days at 4x (headless ~7 ticks/s)
    # Unleash the Disaster button on the village centre.
    page.mouse.click(478, 1238)
    page.wait_for_timeout(500)
    page.mouse.click(360, 640)
    page.wait_for_timeout(30000)  # let the disaster show itself
    page.screenshot(path=f"{OUT}/visual-check-v10-disasters-fit.png")
    for _ in range(3):
        page.mouse.click(680, 98)
        page.wait_for_timeout(500)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v10-disasters-zoomed.png")
    page.mouse.click(268, 98)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v10-disasters-log.png")
    page.screenshot(path=f"{OUT}/visual-check-v10-disasters-crop.png", clip={"x": 180, "y": 420, "width": 360, "height": 360})
    print("pck:", json.dumps(pck_info()))
    print("console-errors:", [c for c in console if c.startswith("error")])
    print("failed_requests:", failed)
    browser.close()
print("screenshots saved")
