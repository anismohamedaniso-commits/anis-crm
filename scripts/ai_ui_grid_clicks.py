from playwright.sync_api import sync_playwright
import time

URL = 'http://127.0.0.1:8000'

with sync_playwright() as p:
    b = p.chromium.launch(headless=False)
    ctx = b.new_context(viewport={'width':1280,'height':800})
    page = ctx.new_page()
    logs = {'console': [], 'network': []}

    page.on('console', lambda msg: logs['console'].append({'type': msg.type, 'text': msg.text}))

    def on_response(resp):
        try:
            if '/api/ai/' in resp.url:
                body = ''
                try:
                    body = resp.text()
                except Exception as e:
                    body = f'body-read-error: {e}'
                logs['network'].append({'url': resp.url, 'status': resp.status, 'body': body[:2000]})
        except Exception as e:
            logs['network'].append({'url': resp.url, 'error': str(e)})

    page.on('response', on_response)

    page.goto(URL, wait_until='networkidle')
    page.screenshot(path='scripts/grid_start.png')

    # Define grid regions (x,y) to click — cover header, right side, center, and footer
    xs = [200, 420, 640, 860, 1080, 1160, 1200]
    ys = [40, 80, 140, 220, 340, 420, 500, 600]

    clicked = []
    for x in xs:
        for y in ys:
            try:
                page.mouse.click(x, y)
                clicked.append((x, y))
                page.wait_for_timeout(400)
                fname = f'scripts/grid_{x}_{y}.png'
                page.screenshot(path=fname)
            except Exception as e:
                logs['console'].append({'type': 'error', 'text': f'Click failed at {(x,y)}: {e}'})

    # Additionally click center area where Run Insights might be
    centers = [(640,420),(640,480),(640,540),(680,420),(600,420)]
    for x,y in centers:
        try:
            page.mouse.click(x,y)
            clicked.append((x,y))
            page.wait_for_timeout(400)
            page.screenshot(path=f'scripts/center_{x}_{y}.png')
        except Exception as e:
            logs['console'].append({'type': 'error', 'text': f'Center click failed {(x,y)}: {e}'})

    # wait a bit for any async activity
    page.wait_for_timeout(3000)

    print('CLICKED POINTS:', clicked)
    print('\nCONSOLE LOGS:')
    for c in logs['console'][-50:]:
        print(c)

    print('\nNETWORK CALLS TO /api/ai/:')
    for n in logs['network']:
        print(n['url'], n.get('status'), n.get('body', '')[:300])

    # Capture a final screenshot
    page.screenshot(path='scripts/grid_end.png')

    print('\nSaved screenshots in scripts/*.png')

    b.close()
