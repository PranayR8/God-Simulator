"""Focused visual check for the plague sick tint / drought tint (Phase 9):
spawn 15 people clustered on open grass (no forest nearby, so a
wildfire falls back to plague or drought), unleash the Disaster button
on them, and screenshot the result. A plague shows sickly green glows
on the ill; a drought parches the map brown.
Saves visual-check-v10b-plague-{fit,zoomed,log}.png.

Coordinates (720x1280): Person tool (613, 1118); Disaster (478, 1238);
log toggle (268, 98); zoom (680, 98); map centre (360, 640).
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
    # 15 people clustered at the centre (they will form a village).
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for i in range(15):
        page.mouse.click(360 + (i % 5) * 15 - 30, 640 + (i // 5) * 15 - 15)
        page.wait_for_timeout(150)
    page.wait_for_timeout(15000)  # let the village form
    # 4x speed, so the plague has time to spread before the screenshot.
    page.mouse.click(540, 32)
    page.wait_for_timeout(300)
    page.mouse.click(540, 32)
    # Unleash the Disaster button on the cluster.
    page.mouse.click(478, 1238)
    page.wait_for_timeout(500)
    page.mouse.click(360, 640)
    page.wait_for_timeout(60000)  # let the plague spread / drought show
    page.screenshot(path=f"{OUT}/visual-check-v10b-plague-fit.png")
    for _ in range(3):
        page.mouse.click(680, 98)
        page.wait_for_timeout(500)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v10b-plague-zoomed.png")
    page.mouse.click(268, 98)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v10b-plague-log.png")
    print("pck:", json.dumps(pck_info()))
    print("console-errors:", [c for c in console if c.startswith("error")])
    print("failed_requests:", failed)
    browser.close()
print("screenshots saved")
