# Code-comment standard for Forecast Lab labs

The instructor's request: **"For all the code, including R code and Python code, provide clear and concise comments so students understand what the code really means."**

Students see lab code in an editor. The `#|` step notes are hidden there; they appear only in *Step through* mode. So every lab needs ordinary `#` comments that make the code readable on its own.

## Rules

1. **Comment every meaningful line, or each small group of related lines.** Say what it does in plain English, and why when it isn't obvious. Include units, what an argument means (`h = 12  # forecast 12 months ahead`), what a result contains, and non-obvious choices (seeds, lags, thresholds, transformations, train/test dates).
2. **Be concise.** Aim for 3 to 12 words, and add a little more only where a student would genuinely be lost. Don't restate the code word for word (`x <- 5  # set x to 5` is useless), and don't repeat the long `#|` step note.
3. **Placement.**
   - Use an end-of-line comment, aligned in a column within a block where practical, when the line stays under about 110 characters.
   - Otherwise put the comment on its own line directly above the code.
   - For a multi-line call, comment after a trailing comma (`viz_compare(a, b,   # …`), or put the comment above the call.
   - Never put a comment after a Python line-continuation backslash or inside a string.
4. **Never start a comment with `#|`.** That prefix is reserved for step notes. Keep every existing `#|` note exactly as it is.
5. **Never change behavior.** Don't change, reformat, rename or reorder any code. Only add comments, and fix an existing comment if it is wrong.
6. **Beginner vocabulary.** Explain idioms the first time they appear in a file, for example:
   - R: `window()`, `ts`, `lag`, `apply`, `sapply`, `%in%`, `[ , ]` indexing, `glm(family = binomial)`
   - Python: `.loc`, `.shift()`, `.resample()`, method chaining, `np.where`, list comprehensions
   - Name the statistical idea (e.g. "rolling-origin cross-validation", "odds ratio = exp(coef)").
7. **Same idea, same words in R and Python.** When a lab exists in both languages, the comments should explain the same steps the same way, noting any language differences.
8. **Exercises.**
   - **Starter files** (with `______` blanks): comment each blank with what it needs, and give a hint level that does not reveal the answer (e.g. `# the seasonal naive function`, not `# use snaive`).
   - **Solution files:** fully comment them.
   - **`*_check.*` files** (hidden from students): leave them alone, apart from an optional one-line header.
9. **Hidden setup files** (`setup*`, `features_setup*`) and generator scripts (`make_data*`, `build_data*`): add a short header comment explaining what they prepare. Line-by-line comments are optional.
10. **Section headers inside long labs** may use `# ── Step name ──` style lines.

## Exemplar

`src/labs/ch03/benchmarks.R` is the reference for style and density.

## Verify (required)

Before editing a file, capture its output. After editing, confirm the output is identical.

```
"/c/Program Files/R/R-4.4.3/bin/Rscript.exe" tools/check_lab.R <file.R> > before.txt   # (R)
python tools/check_lab.py [--setup <setup.py>] <file.py>   > before.txt              # (Python)
```

Run this from `C:\Users\zheng\Forecasting\site`. Write before/after files in your scratch area, not in the repo. Diff the before and after outputs: they must match except for timing numbers. Labs that use a hidden setup must be run with the setup prepended. For R, concatenate the setup file and the lab into a temporary file outside `src/`. For exercises, run solution then check.
