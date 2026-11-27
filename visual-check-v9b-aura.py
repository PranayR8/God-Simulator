"""Focused visual check for the blessed-person aura (Phase 8): spawn a
few people at the map centre, bless one, zoom in and screenshot so the
golden glow + gold ring are legible. Fast (~40s) — no village needed.
Saves visual-check-v9b-aura-fit.png and -zoomed.png.

Coordinates (720x1280): Person tool (613, 1118), Bless Person (75, 1238),
Zoom in (680, 98), map centre (360, 640).
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
    # Spawn 5 people clustered at the centre.
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for (dx, dy) in [(0, 0), (15, 10), (-12, 8), (8, -14), (-8, -6)]:
        page.mouse.click(360 + dx, 640 + dy)
        page.wait_for_timeout(200)
    # Bless the one at the centre.
    page.mouse.click(75, 1238)
    page.wait_for_timeout(500)
    page.mouse.click(360, 640)
    page.wait_for_timeout(2000)
    page.screenshot(path=f"{OUT}/visual-check-v9b-aura-fit.png")
    for _ in range(3):
        page.mouse.click(680, 98)
        page.wait_for_timeout(500)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v9b-aura-zoomed.png")
    print("pck:", json.dumps(pck_info()))
    print("console-errors:", [c for c in console if c.startswith("error")])
    print("failed_requests:", failed)
    browser.close()
print("screenshots saved")
