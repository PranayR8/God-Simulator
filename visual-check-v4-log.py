"""Visual check for Phase 1 (event log): load the game, cluster-spawn
people so a village founds, strike it with lightning, then screenshot
the log panel collapsed (default) and expanded (after clicking Show).
Saves visual-check-v4-log-collapsed.png and -expanded.png.

NOTE: Godot draws its whole UI inside one <canvas> — there are no DOM
buttons. Every interaction here is by viewport coordinates (720x1280):
  Speed button .... (540, 32)     Person tool .... (580, 1178)
  Bolt tool ....... (324, 1238)   Log Show toggle  (268, 98)
  Map centre ...... (360, 640)
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
    # Cluster-spawn 12 people near the map centre (Person tool, then
    # taps). Fast and dense: a village only founds when 6+ people are
    # within 4 tiles at a scan, and people diffuse quickly.
    page.mouse.click(580, 1178)
    page.wait_for_timeout(500)
    for dx, dy in [(0, 0), (14, 0), (-14, 0), (0, 14), (0, -14), (14, 14),
                   (-14, -14), (7, -7), (-7, 7), (7, 7), (-7, -7), (0, 7)]:
        page.mouse.click(360 + dx, 640 + dy)
        page.wait_for_timeout(120)
    page.wait_for_timeout(60000)  # ~8 days at 4x: village founds, births happen
    # Strike the cluster with lightning (Bolt tool, then a tap).
    page.mouse.click(324, 1238)
    page.wait_for_timeout(500)
    page.mouse.click(360, 640)
    page.wait_for_timeout(15000)
    page.screenshot(path=f"{OUT}/visual-check-v4-log-collapsed.png")
    # Expand the log and screenshot the full history.
    page.mouse.click(268, 98)
    page.wait_for_timeout(1500)
    page.screenshot(path=f"{OUT}/visual-check-v4-log-expanded.png")
    print("pck:", json.dumps(pck_info()))
    print("console-errors:", [c for c in console if c.startswith("error")])
    print("failed_requests:", failed)
    browser.close()
print("screenshots saved")
