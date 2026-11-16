# Trimming pass: fundamentals first

The instructor's verdict on the deepened chapters: **too dense. It is impossible to cover all of this in two 75-minute sessions.** Keep the **most fundamental** content. Once a basic concept has been introduced, its more advanced versions, extra cases and extensions **can wait for later**.

Read `DEEPEN.md` for background (two 75-minute sessions, interpretation and data transformations first, undergraduate level). This pass *reduces* the main path; it adds nothing new.

## Budget for the main path (both sessions together)

Measure with `python tools/density.py <slug>` (counts everything before the Beyond box and the instructor kit).

| | Most chapters | Ch 5 (two-part chapter) |
|---|---|---|
| Prose (excluding code, the instructor kit and the Beyond box) | **≤ 3,200 words** | ≤ 4,500 words |
| Code labs in the main path (including exercises) | **≤ 5** | ≤ 8 |
| …of which exercises | ≤ 2 | ≤ 2 |
| Explorables | **≤ 5** | ≤ 7 |
| Predict checks | ≤ 5 | ≤ 7 |
| Empirical-tip callouts | **≤ 4** (the most fundamental) | ≤ 5 |

These are ceilings, not targets. Under them is fine.

## How to decide what stays

Keep, in this order:
1. The chapter's **core idea** and the one tool it teaches, with its plain-words interpretation (what the output means, in units).
2. The **one or two transformation/interpretation tips** students will use most (e.g. why we take logs here; how to read this coefficient).
3. The chapter's **payoff**: the "you will build" result and one applied exercise.
4. The best explorable for each core idea (one picture per idea, not three).

Move out of the main path:
- Advanced extensions and refinements of an idea already introduced (robust standard errors, decompositions of a score, alternative estimators, tests beyond the first one, extra horizons, special cases, "under the hood" machinery).
- A second or third example of the same lesson; a second explorable for an idea that already has one.
- Long caveat sections, historical asides, robustness checks, extra datasets.
- Exercises beyond the two best ones (they become "Extra practice").

Delete outright only content that re-teaches what another chapter owns (replace it with one sentence and a link).

## Where moved content goes

- Put it in one collapsed box at the end of the chapter, **after the "Chapter checklist" and before `<InstructorKit`**:
  ```mdx
  import BeyondBasics from '../../components/BeyondBasics.astro';
  …
  <BeyondBasics topics={['Newey–West standard errors', 'Brier decomposition', 'Extra practice']}>

  #### Newey–West standard errors
  …moved text, labs, explorables…

  </BeyondBasics>
  ```
- Inside the box use `####` headings only (they stay out of the "On this page" list). Keep each moved section's **heading text unchanged**, so anchors other chapters link to still work (a link into the box opens it automatically).
- Edit moved text so it still reads correctly on its own: no "as we just saw" that no longer fits; forward references point down into the box ("see Beyond the basics below").
- The main text must not depend on anything in the box. Where it used to, replace that with one short sentence or remove the reference.

## Then make everything agree

- **Sessions:** re-balance so each session realistically fits 75 minutes **with slack**: at most ~60 minutes of planned material plus ~10–15 minutes for questions and transitions. Update the `SessionBreak` goals, frontmatter `sessions` (and `starts:` if the first session-2 heading moved), and the InstructorKit `sessions` plans (lines still sum to 75; include a buffer line such as `'10 min · Buffer: questions, catch-up'`).
- Frontmatter: `minutes:` (realistic self-study time for the main path), `build:` and `skills:` list only main-path content.
- InstructorKit: objectives, discussion and misconceptions cover only main-path content (you may add one line "Optional extensions: see Beyond the basics"). Each session's activity must use only main-path material.
- Chapter checklist: fundamentals only.
- References: keep every reference still cited anywhere on the page (including the box). Remove references no longer cited and **renumber** superscripts and the list consistently.
- Ch 12 labs are titled "Lab 12.x": keep the numbering consecutive in the main path; moved labs drop their number.

## Rules (15 agents work in parallel)

- Edit only your own chapter `.mdx` (and, if needed, your own components/labs folder). Do not edit shared files (`src/components/*.astro|*.svelte` at the top level, layouts, lib, tools, config, other chapters).
- Do not change numbers; you are moving text, not recomputing. If a moved lab changes, re-run it (`python tools/check_all.py <folder>`).
- No `git` commands that change state; no `npm install`.
- Name every scratch file with your slug prefix. Build into your own folder: `npx astro build --outDir C:/Users/zheng/AppData/Local/Temp/claude/bbc50bc65206660f/2ea606fa-73a9-416b-bc78-057b306a0df2/scratchpad/trim-<slug>` (retry on a transient `.astro` cache collision), then `python tools/crawl.py <that folder>` must show **0 problems**.
- Screenshots: stop any server before rebuilding; serve your build with `python -m http.server <4600 + chapter number> -d <folder>`, then `SHOTS_BASE=http://localhost:<port> SHOTS_OUT=<scratch>/trim-shots-<slug> python tools/shots.py <slug>`: 0 overflow, 0 console errors. Stop the server when done.

## Report (under 350 words)

Before → after counts (words, labs, exercises, explorables, Predicts, empirical tips); what each session now covers in one line each; the list of items moved to Beyond the basics; anything deleted; verification results.
