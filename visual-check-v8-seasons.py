"""Visual check for Phase 7 (seasons): load the game, cluster-spawn 30 people
at the map centre, run at 4x and wait ~110s so the spawned people grow
past 12 days (1440 ticks = 90s at 4x) into adults and get jobs, then
screenshot the world (fit zoom) and zoomed in on the village (job dots
above heads + tunic trim, forest edge receding), with the History panel
expanded so the "took up work" lines are visible.
Also saves a 3x-upscaled crop around the village centre so the small
job markers are legible.
Saves visual-check-v8-seasons-fit.png, -zoomed.png, -log.png, -crop.png.

NOTE: Godot draws its whole UI inside one <canvas> — there are no DOM
buttons. Every interaction here is by viewport coordinates (720x1280):
  Speed button .... (540, 32)     Person tool .... (580, 1178)
  Zoom in ......... (680, 98)     Log Show toggle  (268, 98)
  Map centre ...... (360, 640)
The village is founded at the centre, so zooming in keeps it centred.
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
    page.mouse.click(580, 1178)
    page.wait_for_timeout(500)
    random.seed(11)
    for _ in range(30):
        dx = random.randint(-20, 20)
        dy = random.randint(-20, 20)
        page.mouse.click(360 + dx, 640 + dy)
        page.wait_for_timeout(100)
    # Wait for the spawned people to grow up (12 days = 1440 ticks).
    # The headless browser runs ~7 ticks/sec at 4x (SwiftShader is
    # slow), so 260s is ~1800 ticks / 15 days — past adulthood, with
    # jobs assigned and the woodcutters already clearing.
    page.wait_for_timeout(320000)
    page.screenshot(path=f"{OUT}/visual-check-v8-seasons-fit.png")
    # Zoom in on the village for the job markers and forest edge.
    for _ in range(3):
        page.mouse.click(680, 98)
        page.wait_for_timeout(500)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v8-seasons-zoomed.png")
    # Expand the log to show the hire lines.
    page.mouse.click(268, 98)
    page.wait_for_timeout(1500)
    page.screenshot(path=f"{OUT}/visual-check-v8-seasons-log.png")
    print("pck:", json.dumps(pck_info()))
    print("console-errors:", [c for c in console if c.startswith("error")])
    print("failed_requests:", failed)
    browser.close()

# 3x-upscaled crop around the village centre from the zoomed shot, so
# the small job dots above heads are legible.
img = Image.open(f"{OUT}/visual-check-v8-seasons-zoomed.png")
crop = img.crop((180, 460, 540, 820)).resize((1080, 1080), Image.NEAREST)
crop.save(f"{OUT}/visual-check-v8-seasons-crop.png")
print("screenshots saved")
