# Deepening pass: brief for every chapter

The instructor teaches **each chapter in two 75-minute class sessions** (about 150 minutes of class per chapter). Your job is to make your chapter fill those two sessions well. The goal is **depth, not breadth**.

## What the instructor asked for, in priority order

1. **Interpretation and empirical practice come first; theory comes last.** What matters most is how students *read* and *use* a model's output, not how the model is built. Go deeper on:
   - how to **interpret coefficients and outputs** in plain words, with units ("a 1-point rise in X goes with a 0.4% rise in Y, holding Z fixed"), and how *not* to read them;
   - **data transformations and why**: when and why to take logs, growth rates, differences, year-over-year changes, seasonal adjustment, real vs nominal, per-capita, index numbers, rescaling units; what each transformation does to the *interpretation* of a coefficient or forecast; and how to transform a forecast back to the original units;
   - **empirical tips**: the practical judgement calls a working analyst makes (checking units and frequencies, plotting before modelling, spotting breaks/outliers, choosing a sample, sanity-checking magnitudes, reporting results honestly).
2. **No new topics, no new models.** Do not introduce a method, test or model the chapter does not already cover. You may use a simpler tool the course already taught (e.g. a scatter plot, a log, a growth rate) to explain your chapter's tool.
3. **Better intuition.** Add a few more **visualizations / explorables** that make an existing idea click. Each must earn its place: one hard idea, one picture, something to drag or toggle, and a one-line takeaway.
4. **More chances to apply.** Add realistic, scaffolded practice: "you are the analyst" tasks on real data, with clear business questions.
5. **Not too difficult for undergraduates.** Plain English, short sentences, concrete numbers. Every formula stays in a collapsible `<Callout type="math">` box and the main text must make sense without it. Exercises are scaffolded: blanks (`______`), hints, a solution and an auto-check. Prefer one idea per step.
6. **Learn from top programs.** Before writing, spend a little time (a few web searches) on how leading courses and textbooks teach *your chapter's* topic and borrow their best teaching moves (not their text). Good starting points: Hyndman & Athanasopoulos, *Forecasting: Principles and Practice* (3rd ed., otexts.com/fpp3); Robert Nau's Duke "Statistical forecasting" notes (people.duke.edu/~rnau/411home.htm — excellent on logs, differencing and interpreting coefficients); Stock & Watson and Wooldridge undergraduate econometrics; course pages from top universities (e.g. Wharton, MIT, Stanford, Berkeley, Chicago Booth, LSE, NYU Stern). Name in your report the 2–4 sources whose ideas you used. Do not copy text or figures; cite in the chapter's reference list if you use a specific idea or number.

## Deliverables for your chapter

1. **The two-session split, visible to students.**
   - Add `import SessionBreak from '../../components/SessionBreak.astro';`.
   - Frontmatter:
     ```yaml
     sessions:
       - title: <session 1 title>
       - title: <session 2 title>
         starts: <slug of the first ## heading of session 2>   # e.g. "why-take-logs"
     ```
     (A heading's slug is lower-case, punctuation removed, spaces to hyphens: "Odds, log-odds and the logistic curve" → `odds-log-odds-and-the-logistic-curve`.)
   - Place `<SessionBreak n={1} title="…" goals={['…', '…', '…']} />` right after the chapter's opening KeyIdea/intro, and `<SessionBreak n={2} … />` immediately before the first `##` heading of session 2. Use the same titles as the frontmatter. 2–4 short goals each.
   - Balance: each session should hold about 75 minutes of class (reading + running labs + explorables + discussion). Session 2 should end with the chapter's main "build it / apply it" payoff.
   - Update `minutes:` in the frontmatter to the realistic self-study time.
2. **Empirical depth.** Add at least **3** `<Callout type="empirical" title="…">` boxes where they matter, each a concrete, actionable tip tied to this chapter's data (e.g. "Why we model log retail sales", "Read a log-log coefficient as an elasticity", "Difference before you correlate trending series"). Add or expand short prose sections on interpretation where the chapter is thin. Use real numbers from your labs.
3. **2–3 new explorables** (Svelte 5, `client:load`, in your chapter's components folder), each targeting one hard interpretation/intuition idea. Distinct from your existing explorables and from other chapters' designs; follow `AUTHORING.md` §5 (instant pure JS, real bundled data where possible, accessible labels, keyboard, works at 390 px wide, light and dark themes via the theme helpers in `src/lib/viz/theme.ts`). If you need precomputed results, write a small native R script in your labs folder that writes JSON (see `src/labs/nonlinear/make_data.R`) and commit both.
4. **At least 2 new applied exercises** (R and Python, auto-checked) framed as realistic tasks ("Your manager asks…"). File names: `exercise2.R`, `exercise2_solution.R`, `exercise2_check.R` (and `.py`), or `ex_<name>.R` / `ex_<name>_solution.R` / `ex_<name>_check.R`. Each solution + check must pass natively. Keep them short (5–15 lines to fill), one skill each, with 2–3 hints. Add `<Predict>` quick checks where they help (2–4 more per chapter is plenty).
5. **Lab code** follows `COMMENTING.md` (clear, concise comments; `#|` step notes in plain English). If you edit existing labs, keep their verified numbers consistent with the text.
6. **Instructor kit**: add the `sessions` prop with a minute-by-minute plan for each session that sums to about 75 minutes (each line starts with its minutes, e.g. `'10 min · Warm-up Predict: …'`), and make the activity slot contain **one activity per session** with expected results. Keep objectives, discussion prompts and misconceptions in step with the new content.
7. **Checklist** at the end updated to include the key interpretation and transformation lessons.

## Cross-chapter ownership (avoid duplication; link instead of re-teaching)

- **Ch 1 (time-series-data)** owns the general transformation primer: levels vs logs vs growth rates vs differences vs year-over-year; real vs nominal; per-capita; seasonally adjusted vs not; index numbers and units. Others link to it (`[Chapter 1](/chapters/time-series-data/#<anchor>)`).
- **Ch 2 (decomposition)**: additive vs multiplicative seasonality and when a log turns one into the other; reading seasonally adjusted numbers.
- **Ch 4 (regression)** owns coefficient interpretation: level-level, log-level, level-log, log-log (elasticity), dummies, units/rescaling, "holding other things fixed", prediction vs causation. Others link to it.
- **Ch 7 (arima)** owns why and when to difference (trends, unit roots in practice), log + difference ≈ growth rate, reading AR coefficients as persistence/half-life.
- **Ch 10 (uncertainty)** owns reading intervals and back-transforming forecasts from logs (median vs mean).
- Every other chapter: interpretation tips specific to its own tool (e.g. ETS smoothing parameters as "memory", impulse responses in the shock's units, odds ratios, variable importance vs causation, nowcast revisions).

## Rules for working in parallel (15 agents edit the site at the same time)

- **Edit only your own files:** your chapter's `.mdx`, your components folder, your labs folder, and your hero only if needed. Folder names are historical; the mapping is in `AUDIT.md`.
- **Do not edit shared files:** `public/r/course.R`, `public/py/course.py`, `src/layouts/*`, `src/lib/*`, `src/components/*.astro|*.svelte` at the top level (CodeLab, Callout, SessionBreak, InstructorKit, …), `astro.config.mjs`, `tools/*`, `package.json`, other chapters' files, data files. If you need a change there (e.g. a new `viz_*` helper or a new dataset), report it instead; for a new chart type use `viz_custom(...)` with a `registerViz` in your own folder (see `src/components/ch05/viz.ts`).
- Do not run `git` commands that change state, and do not run `npm install`.
- **Build into your own folder** so builds don't collide: `npx astro build --outDir C:/Users/zheng/AppData/Local/Temp/claude/bbc50bc65206660f/2ea606fa-73a9-416b-bc78-057b306a0df2/scratchpad/build-<slug>` then `python tools/crawl.py <that folder>` (0 problems required). If the build fails because of *another* chapter's in-progress edit, wait a minute and retry; do not touch their file.
- **Screenshots**: serve your build folder with `python -m http.server <port> -d <folder>` (port = 4500 + your chapter number) in the background, then `SHOTS_BASE=http://localhost:<port> SHOTS_OUT=<scratch>/shots-<slug> python tools/shots.py <slug>` (0 overflow, 0 console errors at 1440 and 390 px). Look at the PNGs of your new explorables.
- **Labs natively**: `python tools/check_all.py <your labs folder>` (all OK). **Labs in the browser**: `python tools/browser_audit.py <slug> http://localhost:<port>` (no errors; exercises show "✓ Correct").
- Stop your http server when done.

## Your final report (under 500 words)

Session titles and where the split falls; each addition (explorables, empirical tips, exercises, Predicts) in one line each; sources from top programs you drew on; verification results (labs native + browser, build, crawl, screenshots); anything you need changed in a shared file.
