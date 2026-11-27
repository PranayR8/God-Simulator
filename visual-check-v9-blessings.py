"""Visual check for Phase 8 (blessings): load the game, cluster-spawn 30
people at the map centre, run at 4x and wait ~240s so a village forms
and grows (~day 13), then use the three blessings and screenshot:
the golden aura on a blessed person, the gold border on a blessed
village, the fertile-rain berries, and the blessing lines in History.
Saves visual-check-v9-blessings-fit.png, -zoomed.png, -log.png, -crop.png.

NOTE: Godot draws its whole UI inside one <canvas> — there are no DOM
buttons. Every interaction here is by viewport coordinates (720x1280).
The toolbar grew a third row in Phase 8 (BottomBar offset_top -196),
so the rows are now: row 1 y=1118, row 2 y=1178, row 3 y=1238.
  Speed button .... (540, 32)     Person tool .... (613, 1118)
  Bless Person .... (75, 1238)    Bless Village .. (209, 1238)
  Fertile Rain .... (344, 1238)   Zoom in ........ (680, 98)
  Log Show toggle . (268, 98)     Map centre ..... (360, 640)
The village is founded at the centre, so zooming in keeps it centred.
A Bless Person tap needs to land within 2 tiles of a person; the
village is dense enough that any tap near the centre should find one,
so three nearby taps are tried (a miss spends no cooldown).
"""
import json, urllib.request, random
from playwright.sync_api import sync_playwright
from PIL import Image

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
    page.wait_for_timeout(10000)  # engine + world load
    # 4x speed so days pass fast (Speed button top-right, twice: 1x->2x->4x).
    page.mouse.click(540, 32)
    page.wait_for_timeout(500)
    page.mouse.click(540, 32)
    page.wait_for_timeout(500)
    # Cluster-spawn 30 people at the centre (Person tool, then taps).
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    random.seed(11)
    for _ in range(30):
        dx = random.randint(-20, 20)
        dy = random.randint(-20, 20)
        page.mouse.click(360 + dx, 640 + dy)
        page.wait_for_timeout(100)
    # Wait for the village to form and grow (~day 13). The headless
    # browser runs ~7 ticks/sec at 4x, so 240s is ~1700 ticks.
    page.wait_for_timeout(240000)
    # Bless Village: tap inside the territory (the village is at the
    # centre, its border is wide).
    page.mouse.click(209, 1238)
    page.wait_for_timeout(500)
    page.mouse.click(360, 640)
    page.wait_for_timeout(1000)
    # Bless Person: three taps near the centre — the village is dense,
    # so one should land within 2 tiles of a person (a miss spends
    # no cooldown, so the extra taps are harmless).
    page.mouse.click(75, 1238)
    page.wait_for_timeout(500)
    for (x, y) in [(360, 640), (340, 660), (380, 620)]:
        page.mouse.click(x, y)
        page.wait_for_timeout(600)
    # Fertile Rain: tap the village centre (forest inside the territory).
    page.mouse.click(344, 1238)
    page.wait_for_timeout(500)
    page.mouse.click(360, 640)
    page.wait_for_timeout(2000)
    page.screenshot(path=f"{OUT}/visual-check-v9-blessings-fit.png")
    # Zoom in on the village for the golden aura and gold border.
    for _ in range(3):
        page.mouse.click(680, 98)
        page.wait_for_timeout(500)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v9-blessings-zoomed.png")
    # Expand the log to show the blessing lines.
    page.mouse.click(268, 98)
    page.wait_for_timeout(1500)
    page.screenshot(path=f"{OUT}/visual-check-v9-blessings-log.png")
    print("pck:", json.dumps(pck_info()))
    print("console-errors:", [c for c in console if c.startswith("error")])
    print("failed_requests:", failed)
    browser.close()

# 3x-upscaled crop around the village centre from the zoomed shot, so
# the golden aura and gold border are legible.
img = Image.open(f"{OUT}/visual-check-v9-blessings-zoomed.png")
crop = img.crop((180, 460, 540, 820)).resize((1080, 1080), Image.NEAREST)
crop.save(f"{OUT}/visual-check-v9-blessings-crop.png")
print("screenshots saved")
