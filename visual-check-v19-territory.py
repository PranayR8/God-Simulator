"""Visual check Phase 19: square territories + exploration.
Spawns a village, lets it grow, and screenshots the blocky border and
any villagers out exploring past it.
Saves visual-check-v19-territory.png and visual-check-v19-explore.png.
"""
from playwright.sync_api import sync_playwright

BASE = "http://localhost:8931"
OUT = "/home/hatch/workspace/god-simulator-checks"

with sync_playwright() as p:
    browser = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    page = browser.new_page(viewport={"width": 720, "height": 1280})
    console = []
    page.on("console", lambda m: console.append(f"{m.type}: {m.text}"))
    page.goto(BASE + "/index.html?v=territory", wait_until="load", timeout=60000)
    page.wait_for_timeout(8000)
    # Forest around the centre, then 14 people fast.
    page.mouse.click(346, 1118)
    page.wait_for_timeout(400)
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            page.mouse.click(360 + dx * 11, 640 + dy * 11)
            page.wait_for_timeout(30)
    page.mouse.click(613, 1118)
    page.wait_for_timeout(400)
    for i in range(14):
        page.mouse.click(360 + (i % 7) * 9 - 27, 640 + (i // 7) * 9 - 18)
        page.wait_for_timeout(80)
    # 4x speed.
    page.mouse.click(540, 32)
    page.wait_for_timeout(200)
    page.mouse.click(540, 32)
    page.wait_for_timeout(30000)
    page.screenshot(path=f"{OUT}/visual-check-v19-territory.png")
    page.wait_for_timeout(30000)
    page.screenshot(path=f"{OUT}/visual-check-v19-explore.png")
    errors = [c for c in console if c.startswith("error")]
    print("console errors:", len(errors))
    for e in errors[:5]:
        print("  ", e)
    browser.close()
print("done")
