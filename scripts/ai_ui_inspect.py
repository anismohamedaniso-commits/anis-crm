from playwright.sync_api import sync_playwright

URL = 'http://127.0.0.1:8000'

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto(URL, wait_until='networkidle')
    # collect button texts
    buttons = page.evaluate("""() => Array.from(document.querySelectorAll('button')).map(b => ({text: b.innerText, id: b.id, cls: b.className}))""")
    anchors = page.evaluate("""() => Array.from(document.querySelectorAll('a')).map(a => ({text: a.innerText, href: a.getAttribute('href')}))""")
    head = page.content()[:8000]
    print('BUTTONS:\n')
    for b in buttons:
        print(b)
    print('\nANCHORS:\n')
    for a in anchors:
        print(a)
    print('\nPAGE_HEAD (first 8k chars):\n')
    print(head)
    browser.close()
