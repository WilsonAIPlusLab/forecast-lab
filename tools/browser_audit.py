"""Run every CodeLab on one chapter page in headless Chrome (real webR + Pyodide) using tools/audit_labs.js.
Usage (from site/): python tools/browser_audit.py <slug> [base_url]     (default base: http://localhost:4322)
Prints one line per lab and language: charts drawn, any error lines, and the exercise check message."""
import asyncio, io, json, sys
from playwright.async_api import async_playwright
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
SLUG = sys.argv[1] if len(sys.argv) > 1 else "first-forecast"
BASE = sys.argv[2] if len(sys.argv) > 2 else "http://localhost:4322"
JS = open("tools/audit_labs.js", encoding="utf8").read()
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=CHROME, headless=True)
        page = await b.new_page(viewport={"width": 1440, "height": 900})
        errs = []
        page.on("pageerror", lambda e: errs.append(str(e)))
        await page.goto(f"{BASE}/chapters/{SLUG}/", wait_until="networkidle")
        await page.wait_for_timeout(2000)
        await page.evaluate(JS)
        for _ in range(1800):
            await page.wait_for_timeout(2000)
            if await page.evaluate("window.__audit && window.__audit.done"): break
        for r in await page.evaluate("window.__audit.results"):
            print(f"{r['i']:>2} {r['lang']:<6} charts={r['viz']} imgs={r['imgs']} timedOut={r['timedOut']} err={r['err'][:120]!r} check={r['check'][:70]!r}  | {r['title']}")
        print("page errors:", errs[:5])
        await b.close()

asyncio.run(main())
