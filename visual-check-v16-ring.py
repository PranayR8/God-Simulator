"""Focused ring check for Phase 16: after the Inspect panel closes, the
white ring stays on the person you inspected (it was hidden behind
the panel while open). Spawns a village, taps a villager with
Inspect, closes the panel, and screenshots the ring.
Saves visual-check-v16-gear-ring.png.
"""
import urllib.request
from playwright.sync_api import sync_playwright

BASE = "http://localhost:8931"
OUT = "/home/hatch/workspace/god-simulator-checks"

with sync_playwright() as p:
    browser = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    page = browser.new_page(viewport={"width": 720, "height": 1280})
    console = []
    failed = []
    page.on("console", lambda m: console.append(f"{m.type}: {m.text}"))
    page.on("requestfailed", lambda r: failed.append(r.url))
    page.goto(BASE + "/index.html?v=gear-ring", wait_until="load", timeout=60000)
    page.wait_for_timeout(10000)
    page.mouse.click(613, 1118)  # Person tool
    page.wait_for_timeout(500)
    for i in range(12):
        page.mouse.click(360 + (i % 4) * 10 - 15, 640 + (i // 4) * 10 - 10)
        page.wait_for_timeout(100)
    page.wait_for_timeout(3000)
    page.mouse.click(613, 1238)  # Inspect tool
    page.wait_for_timeout(800)
    # Tap a grid around the village centre — the villagers wander,
    # so one of these lands on a person and opens their panel. Then
    # close the panel (the Close button is centred near the bottom
    # of the panel, ~(360, 790)) and the white ring stays on them.
    for pos in [(360, 640), (345, 655), (375, 625), (350, 630), (370, 650), (340, 645)]:
        page.mouse.click(pos[0], pos[1])
        page.wait_for_timeout(900)
    page.mouse.click(360, 790)
    page.wait_for_timeout(1500)
    page.screenshot(path=f"{OUT}/visual-check-v16-gear-ring.png")
    errors = [c for c in console if c.startswith("error") or "Error" in c]
    print("console errors:", errors)
    print("failed requests:", failed)
    browser.close()
print("done")
