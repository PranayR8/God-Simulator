"""Visual check for Phase 18 (more traits + endless game): the HUD
goal line points at the next achievement (no 100-day scenario, no
ending), and the Inspect panel shows the innate trait AND the
acquired traits ("Acquired: ...").
Saves visual-check-v18-traits-{fit,inspect,log}.png.

Coordinates (720x1280): Grass (80, 1118); Forest (346, 1118); Person
(613, 1118); Inspect (613, 1238); Speed (540, 32); log toggle
(268, 98); map centre (360, 640).
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
    page.goto(BASE + "/index.html?v=traits", wait_until="load", timeout=60000)
    page.wait_for_timeout(10000)
    # Forest around the centre (food, so nobody starves).
    page.mouse.click(346, 1118)
    page.wait_for_timeout(500)
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            page.mouse.click(360 + dx * 11, 640 + dy * 11)
            page.wait_for_timeout(40)
    # 14 people at the centre, fast (100ms gaps) — a village forms.
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for i in range(14):
        page.mouse.click(360 + (i % 7) * 9 - 27, 640 + (i // 7) * 9 - 18)
        page.wait_for_timeout(100)
    # 4x is two clicks from 1x.
    page.mouse.click(540, 32)
    page.wait_for_timeout(300)
    page.mouse.click(540, 32)
    # Let the village form and grow (about 40 seconds at 4x).
    page.wait_for_timeout(40000)
    page.screenshot(path=f"{OUT}/visual-check-v18-traits-fit.png")
    # Inspect: pick the Inspect tool, then tap around the village
    # centre until a person is hit (people are small dots — try a
    # grid of taps and stop once the panel opens).
    page.mouse.click(613, 1238)
    page.wait_for_timeout(500)
    found = False
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            page.mouse.click(360 + dx * 14, 600 + dy * 14)
            page.wait_for_timeout(400)
            # The hint text changes once a person is inspected.
            hint = page.evaluate("() => { const el = document.querySelector('canvas'); return el ? 'canvas' : ''; }")
            # Screenshot after each tap is too slow; instead check the
            # panel by looking for the InspectPanel in the DOM text.
            body = page.evaluate("() => document.body.innerText || ''")
            if "Stats" in body or "Acquired" in body:
                found = True
                break
        if found:
            break
    print("inspect found a person:", found)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v18-traits-inspect.png")
    # Open the log to read the History.
    page.mouse.click(268, 98)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v18-traits-log.png")
    errors = [c for c in console if c.startswith("error")]
    print("console errors:", len(errors))
    for e in errors[:5]:
        print("  ", e)
    print("failed requests:", failed)
    print("console lines:", len(console))
    browser.close()
print("done")
