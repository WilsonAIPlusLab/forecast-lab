# Forecast Lab: chapter authoring guide

You are writing **one chapter** of Forecast Lab, an interactive website for an undergraduate *Economic & Business Forecasting* course (ECON 3371, University of Northern Iowa). Students read a concept, run and edit real R or Python code **in the browser**, step through it line by line, and get polished, employer-ready results.

## 0. The bar (read this twice)

- The owner wants instructors at other universities to see this site and think *"this is the only website I need to teach this course."* Treat that as the acceptance test.
- **Application first.** Every concept is reached through something the student runs or manipulates. Theory lives in collapsible "Show the math" boxes, not in the main path.
- **Each chapter must look and feel different, designed around its own content.** The shared chrome (code lab, callouts, layout) stays common, but your signature explorables, hero art and narrative form must come from *your* topic. Choose the form that fits: scrollytelling, a simulation, a game, a "predict then reveal", a dashboard, a guided experiment. Ask: *"would this page look the same for any other topic?"* If yes, redesign it.
- **Accuracy is non-negotiable.**
  - Every number in prose must come from code you actually ran (`tools/check_lab.R` / `.py`).
  - Every factual or historical claim needs a source. Use web search to verify, and cite in a References block.
  - State SA/NSA, units and frequency correctly (see `DATA_CATALOG.md`).
  - Do not invent statistics or quotes.
- **Wording:**
  - Plain, direct, warm, precise. Short sentences. Second person ("you").
  - No marketing filler ("unlock the power…"). Define every term on first use (use `<Term>` for hover definitions).
  - American English. Sentence case for headings.
- Spend tokens freely on quality: design, verification, polish. Do not cut scope.

## 1. Read first

1. `C:\Users\zheng\Forecasting\CURRICULUM.md`: the course map. Find your chapter row (question, concepts, signature result, data).
2. `C:\Users\zheng\Forecasting\DESIGN_PRACTICES.md`: design rules (charts, motion, a11y, anti-patterns). Follow them.
3. `DATA_CATALOG.md` (this folder): every bundled series, with units and SA/NSA.
4. **The exemplar chapter (match its quality and completeness, not its design):**
   - `src/pages/chapters/benchmarks.mdx`
   - `src/components/ch03/*.svelte` (three explorables)
   - `src/components/heroes/benchmarks.astro` (hero art)
   - `src/labs/ch03/*` (labs, exercise, solution, check)
5. Shared building blocks (read, **do not edit**):
   - `src/components/CodeLab.svelte`
   - `src/components/Explorable.svelte`
   - `src/components/{Callout,KeyIdea,Term,InstructorKit}.astro`
   - `src/components/Predict.svelte`
   - `src/lib/ts.ts` (JS time-series toolkit: loadSeries, ses, holt, holtWinters, benchmarks, accuracy, rng)
   - `src/lib/viz/theme.ts` (C colours, plotStyle, fmt, watchLayout)
   - `src/lib/viz/render.ts` (chart types emitted by viz_*; `registerViz` for custom types)
   - `public/r/course.R`, `public/py/course.py` (helpers available inside labs)

## 2. Files you own (create only these)

```
src/pages/chapters/<slug>.mdx           the chapter (layout: ../../layouts/Chapter.astro, frontmatter slug must match src/lib/chapters.ts)
src/labs/chNN/*.R, *.py                 lab code (NN = two-digit chapter number)
src/components/chNN/*.svelte|.ts        your explorables / custom viz
src/components/heroes/<slug>.astro      signature hero art (SVG + CSS animation, no JS needed)
```

**Do not modify any other file.** Other agents are working in parallel. That includes CodeLab, render.ts, course.R/py, global.css, layouts, chapters.ts, data and other chapters. If you truly need a shared change, implement it locally in your chapter folder (e.g. register a custom chart type, below) and mention it in your final report.

## 3. Page skeleton (adapt the order to your story; do not make it formulaic)

```mdx
---
layout: ../../layouts/Chapter.astro
slug: exponential-smoothing
minutes: 45
build: ["…signature deliverable 1…", "…2…"]      # concrete, employer-impressive outputs
skills: [ets, ses, holt, hw, …]                  # real function/concept names (rendered as code tags)
---
import … (components, ?raw labs)

<p class="lede">Hook: a concrete business/econ situation in 2–4 sentences.</p>
… sections (## headings, sentence case), each: motivation → interactive → explanation → code → check …
## Your turn            ← at least one auto-checked exercise
## Chapter checklist    ← 4–7 bullets
<InstructorKit …>…activity with expected results…</InstructorKit>
<div class="refs" id="refs"> **References** … </div>
```

Put wide figures and labs inside `<div class="breakout"> … </div>`. Use `client:load` on all Svelte components.

## 4. Code labs (`CodeLab`)

```mdx
import fooR from '../../labs/ch05/foo.R?raw';
import fooPy from '../../labs/ch05/foo.py?raw';
<div class="breakout">
<CodeLab client:load id="ch05-foo" title="Short action title" r={fooR} py={fooPy}
  packages={['forecast']} pyPackages={['statsmodels']}
  goal="One sentence: what the student will produce." />
</div>
```

- **Step-through notes.** Lines starting with `#|` are explanations for the code *below* them, until the next `#|` block. They are stripped from the editor and shown in the step panel. They accept markdown (`code`, **bold**, *italic*, `- bullets`). Write one note per logical step (3–8 steps per lab). A note explains *what the line does and why*, and what to notice in the output. This is the heart of the "understand every line" goal, so make the notes excellent.
- **Self-contained.** Each lab loads its own data and libraries. Step mode starts from a fresh session. If several labs share setup, pass `setup={…}` (hidden code run first).
- **R conventions** (match the instructor's existing course): base R + `forecast`, `tseries`, `lmtest`, `sandwich`, `dynlm`, `vars`, `urca`, `strucchange`, `ranger`/`randomForest`, `xgboost`, `rpart`.
  - Use `library()` inside the lab.
  - Declare packages in `packages` so they preload.
  - Keep CPU modest: webR is single-threaded WebAssembly, so keep each lab under ~10 s in the browser (≈ under 2 s natively). Use small `num.trees`/`nrounds`, short `tsCV` windows, and `auto.arima(..., stepwise = TRUE)`.
- **Python** (optional but strongly encouraged on main labs): pandas, numpy, statsmodels, scikit-learn, lightgbm, xgboost (Pyodide).
  - It must produce the same result as the R version, as closely as the libraries allow, and say so where it differs.
  - `fred()` and `viz_*` work the same way, with keyword names (`lag_max`, `from_`).
- **Helpers available in labs** (R names shown; Python is the same):
  - `fred(id, start=, end=, to="month"|"quarter")`
  - `viz_ts(..., title, subtitle, ylab, recessions=TRUE, facet=TRUE, log=TRUE)`
  - `viz_forecast(fc, actual=, from=, fitted=TRUE)`
  - `viz_compare(history=, actual=, Name1 = fc1, …)`
  - `viz_table(df, highlight=c("MAE"), digits=, lower_is_better=)`
  - `viz_lines(x, Name = y, …, xlab, ylab, zero)`
  - `viz_bars(values, labels)`
  - `viz_scatter(x, y, fit=TRUE)`
  - `viz_acf(x, lag.max, type="acf"|"pacf")`
  - `viz_decomp(stl_or_decompose)`
  - `viz_kpi(Name = value, …)`
  - `viz_custom(type, ...)`
  - `check_that(cond, pass_msg, fail_msg)`
  - Every chart automatically gets a "Source: FRED (IDs)" line and PNG/SVG export buttons.
  - **Titles should state the takeaway** ("Seasonal naive wins by a wide margin"), not restate the axes.
- **Custom chart types.** In `src/components/chNN/viz.ts`, call `registerViz('my-type', (spec, el, ctx) => { … Observable Plot … })`. Import that file from one of your Svelte components so it registers on page load. Emit from R with `viz_custom("my-type", foo = …)`.
- **Exercises:**

  ```mdx
  <CodeLab client:load id="ch05-ex1" exercise title="Exercise: …" r={exR} solution={exSolR} check={exCheckR}
    hints={['first nudge', 'second, more specific']} packages={['forecast']} goal="What to do." />
  ```

  - Starter code uses `______` (6 underscores) for blanks.
  - The check file runs after the student's code and calls `check_that(...)`, with a pass message that *teaches something extra* (like the ch03 one) and a fail message that diagnoses the likely mistake.
  - Python exercises use `py`, `solutionPy`, `checkPy`.
- **Verify every lab natively before you finish** (from `C:\Users\zheng\Forecasting\site`):

  ```
  "/c/Program Files/R/R-4.4.3/bin/Rscript.exe" tools/check_lab.R src/labs/chNN/*.R
  python tools/check_lab.py src/labs/chNN/*.py
  ```

  - For exercises, run solution + check together, as in the ch03 example.
  - All must print `-> OK`.
  - Use these runs to get the true numbers you quote in prose.

## 5. Explorables (instant, pure JS: the "wow" layer)

- Wrap each in `<Explorable title="…takeaway…" caption="…how to use + what to notice…">` with optional `controls` and `aside` snippets (see `ch03/BenchmarkExplorer.svelte`).
- Real data via `loadSeries()`, so computations are instant (no R wait). Use `src/lib/ts.ts` models or write small local ones.
- Draw with Observable Plot (`@observablehq/plot`) or D3, coloured via `C` from `theme.ts`. Re-render on theme change and resize with `watchLayout`.
- **Design rules:**
  - At most 3 controls per widget.
  - Direct labels instead of legends.
  - Chart text ≥ 12px.
  - Data lines 2–2.5px, highlighted 3px, context 1.25px at 40% opacity.
  - Units in tooltips.
  - Native `<input type=range>` with labels.
  - Keyboard-operable, with an `aria-label` on charts.
  - Respect `prefers-reduced-motion`.
  - No transition while a slider is dragging; 300–450 ms for discrete changes.
- **Pedagogy:** predict → manipulate → explain → check. Use `<Predict>` before reveals (2+ per chapter), and include at least one "what surprised you" moment built from real data quirks (COVID, 2008, structural breaks).
- Aim for **2–4 signature explorables** per chapter, each demonstrating one idea, plus the hero art.

## 6. Hero art (`src/components/heroes/<slug>.astro`)

- Pure SVG + CSS keyframes: one orchestrated ~3 s entrance, then still (or one subtle loop).
- It should express the chapter's core idea at a glance. See `benchmarks.astro` (a race) and `first-forecast.astro` (a fan unfurling).
- Use CSS variables for colour, include a reduced-motion fallback, and keep the viewBox around 520×300–420.

## 7. Prose components

- `<Callout type="intuition|pitfall|business|tip|math" title="…">`. Note that `math` collapses as "Show the math".
- `<KeyIdea>…</KeyIdea>`: one or two per chapter, for the sentence students must remember.
- `<Term def="…">word</Term>`
- `<Predict client:load question=… options=[…] answer={i} explain=… kind="predict|check" />`
- KaTeX math: `$…$` inline, `$$…$$` display. In MDX, escape `{`/`}` inside JSX props. In plain markdown, math is fine. Escape `$` in prose as `\$` when it means dollars next to math.
- Markdown tables are fine (they are styled).
- `<InstructorKit minutes={…} data={[FRED IDs]} objectives={[…]} discussion={[…]} misconceptions={[…]}>`. Its body is an in-class activity with steps and **expected results** (verified by running code).

## 8. Colours

- Chapter accent: `var(--ch)`, already set by the layout from `chapters.ts`.
- Semantic, from `theme.ts`: `C.history`, `C.forecast` (violet), `C.actual` (gold = what really happened), `C.fitted` (cyan).
- Categorical: `C.s[0..5]` (colour-blind safe).
- Text-safe violet is `var(--accent-text)`. Don't use the gradient (`--grad`); it is reserved for the logo.
- Never encode meaning by colour alone.

## 9. Check your page renders

The dev server is already running at http://localhost:4321 (do **not** start another, and do not use the browser pane, which other agents share). Verify with:

```
curl -s -o /dev/null -w "%{http_code}" http://localhost:4321/chapters/<slug>/        # must be 200
curl -s http://localhost:4321/chapters/<slug>/ | grep -c "astro-island"               # your islands present
curl -s -o /dev/null -w "%{http_code}" "http://localhost:4321/src/components/chNN/YourWidget.svelte"   # 200 = compiles
```

If you get a 500, `curl -s http://localhost:4321/chapters/<slug>/ | head -50` shows the error. Also run `npx svelte-check --workspace src/components/chNN` if helpful.

## 10. Final report (your last message)

Report in ≤ 250 words:
- the files created;
- the signature explorables, one line each;
- the verification results (check_lab output lines, curl codes);
- any shared-file change you would recommend;
- anything you could not verify.
