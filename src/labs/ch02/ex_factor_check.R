# Hidden check for ex_factor: recompute the factor and the December 2025 percentage.
.f <- nsa / sa; .p <- 100 * (window(.f, start = c(2025, 12), end = c(2025, 12)) - 1)
.fe <- function(y) as.numeric(window(.f, start = c(y, 2), end = c(y, 2)))
.ok1 <- exists("factor") && is.ts(factor) && isTRUE(all.equal(as.numeric(factor), as.numeric(.f)))
.ok2 <- exists("pct_above") && length(pct_above) == 1 && abs(as.numeric(pct_above) - as.numeric(.p)) < 1e-8
check_that(.ok1 && .ok2,
  sprintf("December 2025 ran %.1f%% above a typical month, so about $75bn of its sales were seasonal, not news. Say it as \"December is %.0f%% above a typical month\", not as a growth rate. Bonus: scroll `factor` to the Februaries. 2024 is %.3f but 2025 is %.3f: the leap day adds about 1/28 = 3.6%% to February's sales, and the factor absorbs it.", .p, .p, .fe(2024), .fe(2025)),
  if (!.ok1) "Step 1: the factor is raw / adjusted, so the raw series `nsa` goes on top." else "Step 2: percent above typical = 100 * (factor - 1), using the December factor stored in `f_dec`.")
