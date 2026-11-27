"""Visual check for a hero (Phase 11): bless a person and confirm they
become a named hero — a golden ring under their feet, a golden aura,
and a log line naming them ("Rhea the Swift became a hero of Wilwick
— blessed by the god"). Also confirms the founder hero: the village's
first citizen gets a gold ring too (no aura, so the ring reads clean).
Saves visual-check-v12-heroes-{fit,zoomed,log}.png.

Coordinates (720x1280): Forest (346, 1118); Person (613, 1118);
Bless Person (75, 1238); log toggle (268, 98); zoom (680, 98);
speed (540, 32); Fit (680, 165); map centre (360, 640).
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
    page.screenshot(path=f"{OUT}/visual-check-v12-heroes-{tag}-fit.png")
    for _ in range(3):
        page.mouse.click(680, 98)
        page.wait_for_timeout(500)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v12-heroes-{tag}-zoomed.png")
    page.mouse.click(268, 98)
    page.wait_for_timeout(1000)
    page.screenshot(path=f"{OUT}/visual-check-v12-heroes-{tag}-log.png")
    page.mouse.click(680, 165)
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
    # Forest around the centre, so the village has food and survives.
    page.mouse.click(346, 1118)
    page.wait_for_timeout(500)
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            page.mouse.click(360 + dx * 11, 640 + dy * 11)
            page.wait_for_timeout(60)
    # 14 people in one cluster, fast (100ms gaps) — they found a village.
    page.mouse.click(613, 1118)
    page.wait_for_timeout(500)
    for i in range(14):
        page.mouse.click(360 + (i % 5) * 12 - 24, 640 + (i // 5) * 12 - 24)
        page.wait_for_timeout(100)
    # Bless a person at the centre RIGHT after spawning, while the
    # cluster is still there — they become a hero too. (Blessing after
    # the 15s wait missed: the people had diffused away from the tap.)
    page.mouse.click(75, 1238)
    page.wait_for_timeout(500)
    page.mouse.click(360, 640)
    page.wait_for_timeout(2000)
    page.wait_for_timeout(15000)  # let the village form (founder hero made)
    # 4x for a minute so the village grows and the log fills in.
    page.mouse.click(540, 32)
    page.wait_for_timeout(300)
    page.mouse.click(540, 32)
    page.wait_for_timeout(60000)
    shot(page, "0")
    print("pck:", json.dumps(pck_info()))
    print("console-errors:", [c for c in console if c.startswith("error")])
    print("failed_requests:", failed)
    browser.close()
print("screenshots saved")
