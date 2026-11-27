"""Visual check for a war (Phase 10), take 2: the first run showed the
villages form but no war — the spawned people are children for 12 days
and a raiding party needs adults, so the war cannot trigger until they
grow up. This run paints forest around both clusters (so the villages
have food and survive to adulthood), spawns the people, runs at 4x,
waits for them to grow up (~12 days), then screenshots every 15s
through the war window to catch the march (red dots), the battle
(red borders + crossed swords) and the log.
Saves visual-check-v11c-wars-{n}-{fit,zoomed,log}.png.

Coordinates (720x1280): Forest (478, 1118); Person (613, 1118);
log toggle (268, 98); zoom (680, 98); speed (540, 32); map centre
(360, 640). Clusters at (258, 640) and (462, 640) — 18 tiles apart.
"""
import json, urllib.request
from playwright.sync_api import sync_playwright

BASE = "http://localhost:8931"
OUT = "/home/hatch/workspace/god-simulator-checks"

def pck_info():
    req = urllib.request.Request(BASE + "/index.pck", method="HEAD")
    with urllib.request.urlopen(req, timeout=10) as r:
        return {"status": r.status, "size": r.headers.get("Content-Length")}

def shot(page, tag):
    page.screenshot(path=f"{OUT}/visual-check-v11c-wars-{tag}-fit.png")
    for _ in range(3):
        page.mouse.click(680, 98)
        page.wait_for_timeout(500)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v11c-wars-{tag}-zoomed.png")
    page.mouse.click(268, 98)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v11c-wars-{tag}-log.png")
    page.mouse.click(680, 165)
    page.wait_for_timeout(500)

with sync_playwright() as p:
    browser = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    page = browser.new_page(viewport={"width": 720, "height": 1280})
    console = []
    failed = []
    page.on("console", lambda m: console.append(f"{m.type}: {m.text}"))
    page.on("requestfailed", lambda r: failed.append(r.url))
    page.goto(BASE + "/index.html", wait_until="load", timeout=60000)
    page.wait_for_timeout(10000)
    # Forest around both clusters, so the villages have food to forage
    # and survive the 12 days until their people grow up.
    page.mouse.click(346, 1118)
    page.wait_for_timeout(500)
    for cx in (258, 462):
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                page.mouse.click(cx + dx * 11, 640 + dy * 11)
                page.wait_for_timeout(60)
    # 25 people per cluster (a Village each, hungry — food starts at 0).
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for cx in (258, 462):
        for i in range(25):
            page.mouse.click(cx + (i % 5) * 12 - 24, 640 + (i // 5) * 12 - 24)
            page.wait_for_timeout(100)
    page.wait_for_timeout(15000)  # let the two villages form
    # 4x speed. The people grow up at 12 days (~210s at 4x in this
    # headless browser); the war triggers as soon as there are adults.
    page.mouse.click(540, 32)
    page.wait_for_timeout(300)
    page.mouse.click(540, 32)
    page.wait_for_timeout(300000)
    # Screenshot every 15s through the war window (march + battle).
    for n in range(6):
        shot(page, str(n))
        page.wait_for_timeout(15000)
    print("pck:", json.dumps(pck_info()))
    print("console-errors:", [c for c in console if c.startswith("error")])
    print("failed_requests:", failed)
    browser.close()
print("screenshots saved")
