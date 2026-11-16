"""Visual audit: screenshot each chapter's hero and every explorable at desktop and mobile widths.
Usage (from site/, with `astro preview --port 4322` running): python tools/shots.py [slug ...]
Writes PNGs to ../_shots/<slug>/ and prints any console errors."""
import sys, os, asyncio
from playwright.async_api import async_playwright

BASE = os.environ.get("SHOTS_BASE", "http://localhost:4322")   # e.g. a static server on your own build folder
SLUGS = sys.argv[1:] or ["first-forecast", "time-series-data", "decomposition", "benchmarks", "regression", "nonlinear-regression", "exponential-smoothing", "arima",
                          "dynamic-regression", "var", "uncertainty", "random-forests", "boosting-shap", "nowcasting", "forecast-studio"]
OUT = os.environ.get("SHOTS_OUT", os.path.join("..", "_shots"))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

async def shoot(browser, slug, width, height, tag):
    page = await browser.new_page(viewport={"width": width, "height": height}, device_scale_factor=1)
    errors = []
    page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
    page.on("pageerror", lambda e: errors.append(str(e)))
    await page.goto(f"{BASE}/chapters/{slug}/", wait_until="networkidle")
    await page.wait_for_timeout(4000)
    d = os.path.join(OUT, slug); os.makedirs(d, exist_ok=True)
    await page.screenshot(path=os.path.join(d, f"{tag}-00-hero.png"))
    await page.evaluate("document.querySelectorAll('details.beyond').forEach(d => d.open = true)")   # include explorables in the optional box
    await page.wait_for_timeout(1000)
    figs = await page.query_selector_all("figure.exp")
    for i, f in enumerate(figs):
        await f.scroll_into_view_if_needed()
        await page.wait_for_timeout(1500)
        try:
            await f.screenshot(path=os.path.join(d, f"{tag}-{i+1:02d}-exp.png"))
        except Exception as e:
            errors.append(f"shot {i}: {e}")
    # horizontal overflow check
    ov = await page.evaluate("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    await page.close()
    return len(figs), errors, ov

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=CHROME, headless=True)
        for slug in SLUGS:
            for (w, h, tag) in [(1440, 900, "d"), (390, 844, "m")]:
                n, errs, ov = await shoot(browser, slug, w, h, tag)
                print(f"{slug} [{tag}] explorables={n} overflow={ov}px errors={len(errs)}" + ("" if not errs else " :: " + " | ".join(e[:160] for e in errs[:3])))
        await browser.close()

asyncio.run(main())
