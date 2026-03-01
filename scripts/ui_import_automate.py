from playwright.sync_api import sync_playwright, TimeoutError
from pathlib import Path

CSV = str(Path(__file__).parent / 'sample_import.csv')
COORDS = [(1160, 40), (1200, 20), (1180, 60), (1160, 720), (1180, 680), (640, 420), (640, 480)]

with sync_playwright() as p:
    b = p.chromium.launch(headless=False)
    ctx = b.new_context(viewport={'width':1280, 'height':800})
    page = ctx.new_page()
    logs = []
    page.on('console', lambda msg: logs.append({'type': msg.type, 'text': msg.text}))

    page.goto('http://127.0.0.1:8000', wait_until='networkidle')
    page.screenshot(path='scripts/ui_before_import.png')

    file_chosen = False
    for coord in COORDS:
        try:
            # start waiting for filechooser before clicking
            with page.expect_file_chooser(timeout=1500) as fc:
                page.mouse.click(coord[0], coord[1])
            chooser = fc.value
            chooser.set_files(CSV)
            print('file chooser set via click', coord)
            file_chosen = True
            break
        except TimeoutError:
            # no file chooser from that click
            continue
        except Exception as e:
            print('error handling file chooser:', e)
            continue

    if not file_chosen:
        print('Failed to trigger file chooser via coordinate clicks; trying keypress to open import dialog...')
        # Try pressing 'i' to open import (not likely)
        try:
            with page.expect_file_chooser(timeout=2000) as fc:
                page.keyboard.press('i')
            chooser = fc.value
            chooser.set_files(CSV)
            file_chosen = True
        except Exception as e:
            print('still failed to trigger file chooser:', e)

    page.wait_for_timeout(1000)
    # After file is chosen, click Import button coordinates roughly centered
    if file_chosen:
        # Try clicking where Import button is likely to appear (center bottom of dialog)
        for c in [(760, 600), (640, 640), (740, 620), (640, 580)]:
            try:
                page.mouse.click(c[0], c[1])
                page.wait_for_timeout(800)
            except Exception as e:
                print('import click failed', c, e)

    page.wait_for_timeout(2000)
    # Read localStorage
    ls = page.evaluate("() => localStorage.getItem('leads_v1')")
    print('LOCALSTORAGE LEN:', len(ls) if ls else 0)
    print('LOCALSTORAGE SAMPLE:', (ls[:500] + '...') if ls and len(ls) > 500 else ls)

    print('\nCONSOLE LOGS:')
    for l in logs:
        print(l)

    page.screenshot(path='scripts/ui_after_import.png')
    b.close()
    print('Done')
