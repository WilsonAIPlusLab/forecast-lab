# Forecast Lab

An interactive, code-first website for **ECON 3371 Economic & Business Forecasting**: 15 chapters, real U.S. data, and R and Python code that runs in the browser (webR and Pyodide), with step-through explanations, instant explorables, auto-checked exercises and an instructor kit for each chapter.

## Run it locally

```bash
npm install
npm run dev          # http://localhost:4321
```

## Publish on GitHub Pages

1. Create a GitHub repository (for example `forecast-lab`) and push this `site/` folder as its root.
2. In the repository, open **Settings → Pages** and set **Source** to **GitHub Actions**.
3. Push to `main`. The workflow in `.github/workflows/deploy.yml` builds the site with the correct base path and publishes it at `https://<your-user>.github.io/<repo>/`.

To build for a custom domain at the root, run `SITE=https://your.domain npm run build`, with no `BASE` set.

## Where things live

| Path | What it is |
|---|---|
| `src/pages/chapters/*.mdx` | Chapter text (one file per chapter) |
| `src/labs/chNN/` | R and Python lab code. Lines starting with `#|` are step-through notes |
| `src/components/chNN/` | Each chapter's interactive figures (Svelte + Observable Plot/D3) |
| `src/components/heroes/` | Animated title art, one per chapter |
| `src/components/` | Shared pieces: `CodeLab`, `Explorable`, `Callout`, `KeyIdea`, `Predict`, `Term`, `InstructorKit` |
| `src/lib/` | Runtimes (`runtime/r.ts`, `runtime/py.ts`), chart renderer (`viz/render.ts`), JS time-series toolkit (`ts.ts`) |
| `public/r/course.R`, `public/py/course.py` | Helpers available in every lab: `fred()`, `viz_*()`, `check_that()` |
| `public/data/` | 71 FRED/CFS series plus 3 UCI teaching datasets (CSV) and `manifest.json` |
| `AUTHORING.md` | How to write or edit a chapter to the site's standard |
| `DATA_CATALOG.md` | Every bundled series, with units and seasonal adjustment |

## Quality tools

```bash
"/c/Program Files/R/R-4.4.3/bin/Rscript.exe" tools/check_lab.R src/labs/ch03/*.R
python tools/check_lab.py [--setup src/labs/ch08/setup.py] src/labs/ch03/*.py
npx astro preview --port 4322 &   # serve the production build, then:
python tools/shots.py             # headless screenshots of every chapter (desktop + mobile), with overflow and console-error checks
```

`tools/audit_labs.js` runs every lab on a page inside the real browser engines and reports errors and timings.

## Updating the data

Run `python tools/update_data.py` to re-download every FRED series from FRED's public CSV endpoint and rebuild `manifest.json`. Numbers quoted in the chapter text were computed from the current files, so after refreshing, re-run the lab checks and update any quoted figures. (Freezing the data per semester keeps the text accurate.)
