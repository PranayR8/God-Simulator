"""Load the live God Simulator, screenshot it, and report console/failed requests.

Fresh browser context (empty cache), so this shows the true current build.
"""
import json
import os
import sys
from urllib.parse import urlparse
from playwright.sync_api import sync_playwright

URL = "http://localhost:8931/"
OUT = "/home/hatch/workspace/god-simulator-godot/visual-check-v3-villages.png"

console_msgs = []
failed = []
pck_info = {}

with sync_playwright() as pw:
    browser = pw.chromium.launch()
    context = browser.new_context(viewport={"width": 720, "height": 1280})
    page = context.new_page()
    page.on("console", lambda m: console_msgs.append(f"{m.type}: {m.text}"))
    page.on("pageerror", lambda e: console_msgs.append(f"pageerror: {e}"))
    page.on("requestfailed", lambda r: failed.append(f"{r.url} :: {r.failure}"))
    page.on("response", lambda r: pck_info.update(
        {"status": r.status, "size": r.headers.get("content-length"),
         "etag": r.headers.get("etag"),
         "last_modified": r.headers.get("last-modified"),
         "cache_control": r.headers.get("cache-control")}
    ) if r.url.endswith("index.pck") else None)
    page.goto(URL, wait_until="load", timeout=60000)
    page.wait_for_timeout(8000)  # engine start
    # Speed button is the "1x" button in the top bar (~x=540, y=32).
    # Two clicks: 1x -> 2x -> 4x, so 150s of waiting is ~20 game days.
    page.mouse.click(540, 32)
    page.wait_for_timeout(500)
    page.mouse.click(540, 32)
    page.wait_for_timeout(150000)
    page.screenshot(path=OUT)
    browser.close()

print("screenshot:", OUT)
print("pck:", json.dumps(pck_info))
print("console:", json.dumps(console_msgs[:20], indent=1))
print("failed_requests:", json.dumps(failed[:10], indent=1))
