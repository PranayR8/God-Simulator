"""Visual check for a war (Phase 10): spawn two big clusters 18 tiles
apart (so they found separately but are in raiding range), run at 4x,
and screenshot during the battle (red borders, clash markers, raider
dots) and after (the war in the History).
Saves visual-check-v11-wars-{fit,zoomed,log}.png (during) and
visual-check-v11b-wars-{fit,zoomed,log}.png (after).

Coordinates (720x1280): Person tool (613, 1118); log toggle (268, 98);
zoom (680, 98); speed (540, 32); map centre (360, 640). The two
clusters go at (258, 640) and (462, 640) — 18 tiles apart in the world.
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
    page.screenshot(path=f"{OUT}/visual-check-v11{tag}-fit.png")
    for _ in range(3):
        page.mouse.click(680, 98)
        page.wait_for_timeout(500)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v11{tag}-zoomed.png")
    page.mouse.click(268, 98)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v11{tag}-log.png")
    # Back to fit for the next round.
    page.mouse.click(680, 98)
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
    # 25 people per cluster (a Village each, hungry — food starts at 0).
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for cx in (258, 462):
        for i in range(25):
            page.mouse.click(cx + (i % 5) * 12 - 24, 640 + (i // 5) * 12 - 24)
            page.wait_for_timeout(100)
    page.wait_for_timeout(15000)  # let the two villages form
    # 4x speed, so the raid, the march and the battle happen fast.
    page.mouse.click(540, 32)
    page.wait_for_timeout(300)
    page.mouse.click(540, 32)
    page.wait_for_timeout(30000)  # the battle should be running now
    shot(page, "-wars")
    page.wait_for_timeout(30000)  # let the war resolve, for the log
    shot(page, "b-wars")
    print("pck:", json.dumps(pck_info()))
    print("console-errors:", [c for c in console if c.startswith("error")])
    print("failed_requests:", failed)
    browser.close()
print("screenshots saved")
