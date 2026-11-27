"""Visual check for Phase 4 (growth stages): load the game, cluster-spawn
~70 people at the map centre so the village climbs Hamlet -> Village ->
Town -> City, then screenshot the world (fit zoom) and zoomed in on the
village (wall ring + keep + stage label), with the History panel expanded
so the "became a Town / became a City" lines are visible.
Saves visual-check-v5-stages-fit.png and -zoomed.png.

NOTE: Godot draws its whole UI inside one <canvas> — there are no DOM
buttons. Every interaction here is by viewport coordinates (720x1280):
  Speed button .... (540, 32)     Person tool .... (580, 1178)
  Zoom in ......... (680, 98)     Log Show toggle  (268, 98)
  Map centre ...... (360, 640)
The village is founded at the centre, so zooming in keeps it centred.
The early screenshot is the important one: at 4x the spawned people
start starving around day 2, so the City is caught ~10s in, before the
population falls back.
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
    page.wait_for_timeout(10000)  # engine + world load
    # 4x speed so days pass fast (Speed button top-right, twice: 1x->2x->4x).
    page.mouse.click(540, 32)
    page.wait_for_timeout(500)
    page.mouse.click(540, 32)
    page.wait_for_timeout(500)
    # Cluster-spawn 70 people at the centre (Person tool, then taps).
    # Small offsets so they all land within a few tiles: the founding
    # scan grabs them as founders, then the rest join, and the village
    # climbs the stages as the taps land.
    page.mouse.click(580, 1178)
    page.wait_for_timeout(500)
    import random
    random.seed(7)
    for _ in range(70):
        dx = random.randint(-20, 20)
        dy = random.randint(-20, 20)
        page.mouse.click(360 + dx, 640 + dy)
        page.wait_for_timeout(100)
    page.wait_for_timeout(3000)  # let the last joins land (~Day 1-2, City)
    page.screenshot(path=f"{OUT}/visual-check-v5-stages-fit.png")
    # Zoom in on the village for the wall ring / keep / houses detail.
    for _ in range(3):
        page.mouse.click(680, 98)
        page.wait_for_timeout(500)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v5-stages-zoomed.png")
    # Expand the log to show the stage lines.
    page.mouse.click(268, 98)
    page.wait_for_timeout(1500)
    page.screenshot(path=f"{OUT}/visual-check-v5-stages-log.png")
    print("pck:", json.dumps(pck_info()))
    print("console-errors:", [c for c in console if c.startswith("error")])
    print("failed_requests:", failed)
    browser.close()
print("screenshots saved")
