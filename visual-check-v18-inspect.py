"""Focused visual check: the Inspect panel opens on a villager and
shows the innate trait AND the acquired traits line.
Saves visual-check-v18-inspect-panel.png.
"""
from playwright.sync_api import sync_playwright

BASE = "http://localhost:8931"
OUT = "/home/hatch/workspace/god-simulator-checks"

with sync_playwright() as p:
    browser = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    page = browser.new_page(viewport={"width": 720, "height": 1280})
    console = []
    page.on("console", lambda m: console.append(f"{m.type}: {m.text}"))
    page.goto(BASE + "/index.html?v=traits2", wait_until="load", timeout=60000)
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
    page.mouse.click(540, 32)
    page.wait_for_timeout(200)
    page.mouse.click(540, 32)
    page.wait_for_timeout(25000)
    # Inspect: tap the village centre and a few offsets.
    page.mouse.click(613, 1238)
    page.wait_for_timeout(400)
    for (x, y) in [(360, 600), (350, 610), (370, 590), (355, 625), (365, 615)]:
        page.mouse.click(x, y)
        page.wait_for_timeout(600)
    page.screenshot(path=f"{OUT}/visual-check-v18-inspect-panel.png")
    errors = [c for c in console if c.startswith("error")]
    print("console errors:", len(errors))
    for e in errors[:5]:
        print("  ", e)
    browser.close()
print("done")
