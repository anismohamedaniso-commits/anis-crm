from playwright.sync_api import sync_playwright
import time

URL = 'http://127.0.0.1:8000'

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context(viewport={'width':1280,'height':720})
    page = context.new_page()
    logs = {'console': [], 'network': []}

    page.on('console', lambda msg: logs['console'].append({'type': msg.type, 'text': msg.text}))
    def on_response(resp):
        try:
            if '/api/ai/' in resp.url:
                logs['network'].append({'url': resp.url, 'status': resp.status, 'body_snippet': resp.text()[:200]})
        except Exception as e:
            logs['network'].append({'url': resp.url, 'error': str(e)})
    page.on('response', on_response)

    page.goto(URL, wait_until='networkidle')
    page.screenshot(path='scripts/s1.png')
    print('saved s1.png')

    # Try clicking top-right where an AI button likely resides
    for coord in [(1160,40),(1200,20),(1120,60),(1180,60)]:
        try:
            page.mouse.click(coord[0], coord[1])
            print('clicked', coord)
            page.wait_for_timeout(800)
            page.screenshot(path=f'scripts/s_click_{coord[0]}_{coord[1]}.png')
        except Exception as e:
            print('click failed', coord, e)

    # Attempt to click center-bottom for Run Insights
    for coord in [(640,420),(640,500),(640,600)]:
        try:
            page.mouse.click(coord[0], coord[1])
            print('clicked run coords', coord)
            page.wait_for_timeout(800)
            page.screenshot(path=f'scripts/s_run_{coord[0]}_{coord[1]}.png')
        except Exception as e:
            print('run click failed', coord, e)

    time.sleep(2)

    print('\nNETWORK CALLS:')
    for n in logs['network']:
        print(n)

    browser.close()
    print('done')
