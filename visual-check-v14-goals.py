"""Visual check for goals (Phase 13): the goal line is visible in the HUD
from the start, and growing a village to 100 citizens before Day 100
shows a victory banner and pauses the game.
Saves visual-check-v14-goals-{start, banner}.png.

Coordinates (720x1280): Forest (346, 1118); Person (613, 1118);
map centre (360, 640). The GoalPanel sits top-right (316,76)-(712,140);
the banner is centred (160,420)-(560,620).
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
    page.goto(BASE + "/index.html?v=goals", wait_until="load", timeout=60000)
    page.wait_for_timeout(10000)
    # The goal line is visible from the start (Day 1, Stone Age).
    page.screenshot(path=f"{OUT}/visual-check-v14-goals-start.png")
    # Forest around the centre, so the village has food.
    page.mouse.click(346, 1118)
    page.wait_for_timeout(500)
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            page.mouse.click(360 + dx * 11, 640 + dy * 11)
            page.wait_for_timeout(60)
    # 100 people in one tight cluster, fast (50ms gaps) — they found a
    # village at ~100 citizens, which wins the scenario outright.
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for i in range(100):
        page.mouse.click(360 + (i % 10) * 8 - 36, 640 + (i // 10) * 8 - 36)
        page.wait_for_timeout(50)
    # Let the village form and the win register (the founding scan runs
    # every 8th tick; the goal check runs every tick). The banner pauses
    # the game when it appears.
    page.wait_for_timeout(30000)
    page.screenshot(path=f"{OUT}/visual-check-v14-goals-banner.png")
    errors = [c for c in console if c.startswith("error") or "Error" in c]
    print("console errors:", errors)
    print("failed requests:", failed)
    browser.close()
print("done")
