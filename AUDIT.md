# Full-site audit brief (Forecast Lab)

The owner asked for agents to check every part of the website so that:

1. Everything is **correct and accurate**: statistics, economics, data facts, numbers, citations.
2. The **wording** is correct and accurate: clear, precise, American English, no typos, no contradictions.
3. The **code works perfectly**: R and Python labs, exercises (starter → hint → solution → check), and explorables.
4. The content is **coherent** with **no errors**: logical flow, consistent terminology, notation and cross-references.
5. All pages are **well connected**: links resolve, chapter references point to the right chapter, and nothing is orphaned.
6. Where needed, there is a way to **go back or navigate**.

The bar: an instructor elsewhere should think "this is the only website I need."

## Ground truth

- Chapters (number · slug · lab folder):
  - 0 · first-forecast · ch00
  - 1 · time-series-data · ch01
  - 2 · decomposition · ch02
  - 3 · benchmarks · ch03
  - 4 · regression · ch04
  - **5 · nonlinear-regression · nonlinear**
  - 6 · exponential-smoothing · ch05
  - 7 · arima · ch06
  - 8 · dynamic-regression · ch07
  - 9 · recession-probability · ch08
  - 10 · var · ch09
  - 11 · uncertainty · ch10
  - 12 · random-forests · ch11
  - 13 · boosting-shap · ch12
  - 14 · nowcasting · ch13
  - 15 · forecast-studio · ch14

  Folder names are historical; *chapter numbers in prose must follow the first column.*
- Pages:
  - `src/pages/chapters/<slug>.mdx`
  - labs: `src/labs/<folder>/`
  - explorables: `src/components/<folder>/`
  - hero art: `src/components/heroes/<slug>.astro`
- Standards:
  - `AUTHORING.md`
  - `COMMENTING.md`
  - `DATA_CATALOG.md`
  - `C:\Users\zheng\Forecasting\DESIGN_PRACTICES.md`
  - `C:\Users\zheng\Forecasting\CURRICULUM.md`
- The dev server runs at http://localhost:4321. **Do not start another server and do not use the browser pane** (another process uses it).
- Check that pages return 200 with `curl`.
- For interactive checks you may write a headless Playwright script with Chrome at `C:\Program Files\Google\Chrome\Application\chrome.exe` (see `tools/shots.py`). Keep scripts and outputs in your own scratch folder under `C:\Users\zheng\AppData\Local\Temp\claude\`, never in the repo.

## How to verify code

From `C:\Users\zheng\Forecasting\site`:

- Run a single lab:
  - R: `"/c/Program Files/R/R-4.4.3/bin/Rscript.exe" tools/check_lab.R <file.R>`
  - Python: `python tools/check_lab.py [--setup <setup.py>] <file.py>`
- Hidden setups:
  - folder `ch08` uses `setup.*`
  - folder `ch12` uses `features_setup.*`
  - folder `nonlinear` uses `setup_bank.*`
  - For R, concatenate the setup and the lab into a temporary file outside `src/`.
- Exercises: run the solution followed by its `_check` file; the check must pass. Also confirm that the starter (with its `______` blanks) is solvable from the hints.
- Every number quoted in prose, captions, Predict explanations, step notes (`#|`), comments and the InstructorKit must match the code's output.
- Verify external facts with web search and make sure they are cited.

## Explorables

- Read the `.svelte`/`.ts` code critically:
  - correct formulas;
  - no look-ahead or leakage;
  - labels and units right;
  - keyboard and reduced-motion support.
- Where practical, drive each explorable in headless Chrome (click every control, move every slider) and look for console errors, NaN/undefined text, empty charts and overlapping labels.

## Rules

- **Edit only the files you are assigned.** Other agents are editing other files in parallel.
- When you edit lab code, re-run it, keep all `#|` step notes valid, and keep comments accurate (COMMENTING.md).
- If something needs a change outside your files, **report it**; do not make it.
- Fix real problems; do not rewrite things that are already correct. Keep each chapter's voice and design.

## Final report

At most 300 words:

- what you checked;
- each problem found and how you fixed it (file:line);
- problems you could not fix, with the reason;
- changes needed in files you do not own.
