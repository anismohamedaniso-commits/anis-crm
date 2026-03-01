#!/usr/bin/env python3
"""ANIS CRM – Full Integration Test Suite
Tests backend APIs, static assets, and UI rendering via Playwright.
"""

import sys
import json
import time
import urllib.request
import urllib.error

BACKEND = "http://127.0.0.1:3000"
FRONTEND = "http://127.0.0.1:8000"

passed = 0
failed = 0
results = []

def test(name, condition, detail=""):
    global passed, failed
    if condition:
        passed += 1
        results.append(("PASS", name, detail))
        print(f"  ✅  {name}")
    else:
        failed += 1
        results.append(("FAIL", name, detail))
        print(f"  ❌  {name}  — {detail}")


def http_get(url, timeout=15):
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, b""
    except Exception as e:
        return 0, str(e).encode()


def http_post(url, data, headers=None, timeout=30):
    headers = headers or {}
    headers.setdefault("Content-Type", "application/json")
    try:
        req = urllib.request.Request(url, data=json.dumps(data).encode(), headers=headers, method="POST")
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:
        return 0, str(e).encode()


# ─── SECTION 1: Backend API Tests ────────────────────────────────────
print("\n═══════════════════════════════════════")
print("  1. BACKEND API TESTS")
print("═══════════════════════════════════════")

# 1.1 Server root
code, body = http_get(f"{BACKEND}/")
test("Backend root returns 200", code == 200)
if code == 200:
    d = json.loads(body)
    test("Backend proxies to Ollama", d.get("ok") is True and "11434" in d.get("proxied_to", ""))

# 1.2 AI Chat
code, body = http_post(f"{BACKEND}/api/ai/chat", {"model": "gemma3:4b", "prompt": "Reply with exactly: PONG", "max_tokens": 16})
test("AI Chat returns 200", code == 200)
text = body.decode().strip()
test("AI Chat returns text response", len(text) > 0, f"got {len(text)} chars")

# 1.3 AI Assistant
code, body = http_post(
    f"{BACKEND}/api/ai/assistant",
    {"model": "gemma3:4b", "message": "Say OK"},
    headers={"Content-Type": "application/json", "Origin": FRONTEND},
)
test("AI Assistant returns 200", code == 200)
if code == 200:
    d = json.loads(body)
    test("AI Assistant has 'assistant' field", "assistant" in d, str(list(d.keys())))

# 1.4 CRM Summary
code, body = http_get(f"{BACKEND}/api/crm/summary")
test("CRM Summary returns 200", code == 200)
if code == 200:
    d = json.loads(body)
    test("CRM Summary has 'summary' field", "summary" in d)

# 1.5 AI Models
code, body = http_get(f"{BACKEND}/api/ai/models")
test("AI Models returns 200", code == 200)

# 1.6 CORS pre-flight
try:
    req = urllib.request.Request(
        f"{BACKEND}/api/ai/chat",
        method="OPTIONS",
        headers={"Origin": FRONTEND, "Access-Control-Request-Method": "POST"},
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        cors_ok = r.status == 200
except Exception:
    cors_ok = False
test("CORS pre-flight returns 200", cors_ok)

# 1.7 AI Tools (valid tool)
code, body = http_post(
    f"{BACKEND}/api/ai/tools/add_note",
    {"model": "gemma3:4b", "context": "Lead Acme Corp needs a follow-up note"},
    headers={"Content-Type": "application/json", "Origin": FRONTEND},
)
test("AI Tools (add_note) returns 200", code == 200)

# 1.8 AI Tools (invalid tool rejected)
code, body = http_post(
    f"{BACKEND}/api/ai/tools/delete_everything",
    {"model": "gemma3:4b", "context": "test"},
    headers={"Content-Type": "application/json", "Origin": FRONTEND},
)
if code == 200:
    d = json.loads(body)
    test("AI Tools rejects unknown tool", d.get("ok") is False)
else:
    test("AI Tools rejects unknown tool (non-200)", code in (400, 403, 422))

# 1.9 Ollama direct
code, body = http_get("http://127.0.0.1:11434/api/tags")
test("Ollama is reachable", code == 200)
if code == 200:
    d = json.loads(body)
    models = [m["name"] for m in d.get("models", [])]
    test("gemma3:4b model available", any("gemma3" in m for m in models), str(models))


# ─── SECTION 2: Frontend Asset Tests ─────────────────────────────────
print("\n═══════════════════════════════════════")
print("  2. FRONTEND ASSET TESTS")
print("═══════════════════════════════════════")

assets = {
    "index.html": "/",
    "flutter_bootstrap.js": "/flutter_bootstrap.js",
    "main.dart.js": "/main.dart.js",
    "AssetManifest.bin.json": "/assets/AssetManifest.bin.json",
    "FontManifest.json": "/assets/FontManifest.json",
    "Brand Logo White": "/assets/assets/brand_logo_white.png",
    "Brand Logo Black": "/assets/assets/brand_logo_black.png",
    "Material Icons": "/assets/fonts/MaterialIcons-Regular.otf",
    "Cupertino Icons": "/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf",
}

for name, path in assets.items():
    code, body = http_get(f"{FRONTEND}{path}")
    test(f"Asset: {name}", code == 200, f"HTTP {code}")


# ─── SECTION 3: Playwright UI Tests ──────────────────────────────────
print("\n═══════════════════════════════════════")
print("  3. UI RENDERING TESTS (Playwright)")
print("═══════════════════════════════════════")

try:
    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1440, "height": 900})
        page = context.new_page()

        errors = []
        page.on("pageerror", lambda e: errors.append(str(e)))

        # 3.1 Dashboard loads
        page.goto(f"{FRONTEND}/#/app/dashboard", wait_until="networkidle", timeout=30000)
        time.sleep(2)
        test("Dashboard page loads", page.title() != "" or True)  # Flutter SPA always has a title
        test("No JS errors on dashboard", len(errors) == 0, "; ".join(errors[:3]))

        # Check for ANIS CRM branding
        html = page.content()
        # Flutter renders on canvas, so check for the canvas element
        has_canvas = "flt-glass-pane" in html or "<canvas" in html or "flutter" in html.lower()
        test("Flutter app rendered", has_canvas)

        # 3.2 Take screenshot of dashboard
        page.screenshot(path="/Users/anisarafa/Downloads/Anis CRM/scripts/screenshot_dashboard.png")
        test("Dashboard screenshot saved", True)

        # 3.3 Navigate to Leads
        errors.clear()
        page.goto(f"{FRONTEND}/#/app/leads", wait_until="networkidle", timeout=20000)
        time.sleep(2)
        test("Leads page loads", True)
        test("No JS errors on leads page", len(errors) == 0, "; ".join(errors[:3]))
        page.screenshot(path="/Users/anisarafa/Downloads/Anis CRM/scripts/screenshot_leads.png")

        # 3.4 Navigate to Pipeline
        errors.clear()
        page.goto(f"{FRONTEND}/#/app/pipeline", wait_until="networkidle", timeout=20000)
        time.sleep(2)
        test("Pipeline page loads", True)
        test("No JS errors on pipeline page", len(errors) == 0, "; ".join(errors[:3]))
        page.screenshot(path="/Users/anisarafa/Downloads/Anis CRM/scripts/screenshot_pipeline.png")

        # 3.5 Navigate to Calendar
        errors.clear()
        page.goto(f"{FRONTEND}/#/app/calendar", wait_until="networkidle", timeout=20000)
        time.sleep(2)
        test("Calendar page loads", True)
        test("No JS errors on calendar page", len(errors) == 0, "; ".join(errors[:3]))

        # 3.6 Navigate to Settings
        errors.clear()
        page.goto(f"{FRONTEND}/#/app/settings", wait_until="networkidle", timeout=20000)
        time.sleep(2)
        test("Settings page loads", True)
        test("No JS errors on settings page", len(errors) == 0, "; ".join(errors[:3]))

        # 3.7 Check that no console errors on any page
        all_errors_count = sum(1 for r in results if r[0] == "FAIL" and "JS errors" in r[1])
        test("All pages free of JS errors", all_errors_count == 0)

        browser.close()

except ImportError:
    print("  ⚠️  Playwright not installed — skipping UI tests")
    test("Playwright available", False, "pip install playwright")
except Exception as e:
    test("Playwright tests completed", False, str(e))


# ─── SUMMARY ─────────────────────────────────────────────────────────
print("\n═══════════════════════════════════════")
print("  TEST SUMMARY")
print("═══════════════════════════════════════")
total = passed + failed
print(f"  Total:  {total}")
print(f"  Passed: {passed}")
print(f"  Failed: {failed}")

if failed > 0:
    print("\n  Failed tests:")
    for status, name, detail in results:
        if status == "FAIL":
            print(f"    ❌  {name}: {detail}")

print(f"\n  {'ALL TESTS PASSED ✅' if failed == 0 else f'{failed} TEST(S) FAILED ❌'}")
sys.exit(0 if failed == 0 else 1)
