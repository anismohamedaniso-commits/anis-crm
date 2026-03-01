from playwright.sync_api import sync_playwright
import time

URL = 'http://127.0.0.1:8000'

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context()
    page = context.new_page()
    logs = {'console': [], 'network': []}

    def on_console(msg):
        logs['console'].append({'type': msg.type, 'text': msg.text})

    page.on('console', on_console)

    def on_response(response):
        try:
            if '/api/ai/' in response.url:
                logs['network'].append({'url': response.url, 'status': response.status, 'headers': dict(response.headers), 'body': response.text()[:2000]})
        except Exception as e:
            logs['network'].append({'url': response.url, 'error': str(e)})

    page.on('response', on_response)

    page.goto(URL, wait_until='networkidle')
    time.sleep(0.5)

    # open AI dialog - assume button with text 'AI' exists
    try:
        page.click('text=AI')
    except Exception:
        # fallback: click Daily Insights directly
        try:
            page.click('text=Daily Insights')
        except Exception as e:
            logs['console'].append({'type': 'error', 'text': f'Click failed: {e}'})

    time.sleep(0.5)

    # click 'Run Insights' if present
    try:
        page.click('text=Run Insights')
    except Exception as e:
        logs['console'].append({'type': 'error', 'text': f'Run Insights click failed: {e}'})

    # wait for network to settle
    page.wait_for_timeout(5000)

    # capture assistant output element if present
    try:
        content = page.locator('#ai-output').inner_text(timeout=1000)
        logs['ai_output'] = content[:5000]
    except Exception:
        logs['ai_output'] = None

    print('CONSOLE LOGS:')
    for c in logs['console']:
        print(c)

    print('\nNETWORK CALLS:')
    for n in logs['network']:
        print(n['url'], n.get('status'), n.get('error', '') )

    print('\nAI OUTPUT:\n', logs['ai_output'])

    browser.close()
