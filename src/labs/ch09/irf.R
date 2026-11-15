#| **Rebuild the VAR(4).** The order of the columns is now a modeling decision: inflation, then unemployment, then the funds rate. You will see why in a moment.
library(vars)
q <- function(id) fred(id, to = "quarter")
y <- na.omit(ts.intersect(400 * diff(log(q("CPIAUCSL"))), q("UNRATE"), q("FEDFUNDS")))
y <- window(y, start = c(1960, 1), end = c(2000, 4))
colnames(y) <- c("infl", "unemp", "ffr")
m <- VAR(y, p = 4, type = "const")

#| **Orthogonalized impulse responses with bootstrap bands.** `irf()` traces how each variable reacts, quarter by quarter, to a one-standard-deviation surprise in `ffr`. `ortho = TRUE` uses the **Cholesky** ordering of the columns: the funds rate is last, so it may react to inflation and unemployment *within the quarter*, but they react to it only from the next quarter on. `runs = 100` resamples the residuals 100 times to get 90% bands (use 500+ for a paper; 100 keeps the browser fast).
set.seed(2001)
b <- irf(m, impulse = "ffr", n.ahead = 20, ortho = TRUE, boot = TRUE, runs = 100, ci = 0.90)
round(cbind(h = 0:8, b$irf$ffr[1:9, ]), 3)

#| **Draw it.** A small helper packs one response per panel, with its band, for the chapter's impulse-response chart. Read the middle panel: unemployment barely moves for a year, then rises by about 0.12 percentage points, peaking two years after the hike.
panel <- function(res, label, ...) {
  runs <- list(...)
  list(name = label, series = lapply(names(runs), function(n) { r <- runs[[n]]
    list(name = n, pt = as.numeric(r$irf$ffr[, res]),
         lo = if (!is.null(r$Lower)) as.numeric(r$Lower$ffr[, res]),
         hi = if (!is.null(r$Upper)) as.numeric(r$Upper$ffr[, res])) }))
}
viz_custom("ch09-irf", h = 0:20, xlab = "quarters after the shock", unit = "pp",
  panels = list(panel("infl", "Inflation", `Fed last` = b), panel("unemp", "Unemployment", `Fed last` = b),
                panel("ffr", "Fed funds rate", `Fed last` = b)),
  title = "A surprise hike: unemployment rises slowly; inflation first rises (the price puzzle)",
  subtitle = "Response to a 0.76 pp funds-rate shock, VAR(4) 1960–2000, 90% bootstrap bands", source = .course_src())

#| **Now put the Fed first.** Same data, same VAR, only the column order changes. With `ffr` first, the Cholesky step assumes the funds rate moves *before* inflation and unemployment can react within the quarter, so their same-quarter co-movement with rates is now credited to the Fed.
m2 <- VAR(y[, c("ffr", "infl", "unemp")], p = 4, type = "const")
b2 <- irf(m2, impulse = "ffr", n.ahead = 20, ortho = TRUE, boot = FALSE)
round(cbind(h = 0:8, `Fed last` = b$irf$ffr[1:9, "unemp"], `Fed first` = b2$irf$ffr[1:9, "unemp"]), 3)

#| **Compare the two stories.** Under "Fed first", a hike *raises* inflation sharply and *lowers* unemployment for a year. That is not new economics: it is a different identifying assumption. The data cannot tell the two orderings apart; only economic reasoning (the Fed sees this quarter's data, but prices and hiring are slow to adjust) can.
viz_custom("ch09-irf", h = 0:20, xlab = "quarters after the shock", unit = "pp",
  panels = list(panel("infl", "Inflation", `Fed last` = b, `Fed first` = b2),
                panel("unemp", "Unemployment", `Fed last` = b, `Fed first` = b2)),
  title = "Same data, two orderings, opposite short-run stories",
  subtitle = "Response to a one-s.d. funds-rate shock; band shown for the baseline ordering only", source = .course_src())
