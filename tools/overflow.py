"""Find elements wider than a 390px mobile viewport on each chapter (from site/, preview on :4322)."""
import sys, asyncio
from playwright.async_api import async_playwright
SLUGS = sys.argv[1:] or ["benchmarks", "forecast-studio", "arima", "uncertainty", "decomposition"]
JS = """() => { const W = document.documentElement.clientWidth; const out = [];
  for (const e of document.querySelectorAll('body *')) { const r = e.getBoundingClientRect();
    if (r.right > W + 1 && r.width > 0) { const p = e.parentElement; const pr = p ? p.getBoundingClientRect() : null;
      if (!pr || pr.right <= W + 1) out.push(e.tagName + '.' + (e.className && e.className.baseVal !== undefined ? e.className.baseVal : e.className) + ' w=' + Math.round(r.width) + ' right=' + Math.round(r.right)); } }
  return out.slice(0, 12); }"""
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=r"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe", headless=True)
        for slug in SLUGS:
            pg = await b.new_page(viewport={"width": 390, "height": 844})
            await pg.goto(f"http://localhost:4322/chapters/{slug}/", wait_until="networkidle"); await pg.wait_for_timeout(2500)
            print(slug, await pg.evaluate(JS)); await pg.close()
        await b.close()
asyncio.run(main())
