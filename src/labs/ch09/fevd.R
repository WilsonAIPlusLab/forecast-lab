#| **Same VAR(4), baseline ordering** (inflation, unemployment, funds rate).
library(vars)                                 # VAR estimation, IRFs, FEVD
q <- function(id) fred(id, to = "quarter")    # helper: FRED series as quarterly averages
# inflation (annualized %), unemployment, funds rate; keep quarters where all three exist
y <- na.omit(ts.intersect(400 * diff(log(q("CPIAUCSL"))), q("UNRATE"), q("FEDFUNDS")))
y <- window(y, start = c(1960, 1), end = c(2000, 4))   # Stock–Watson sample, 1960Q1 to 2000Q4
colnames(y) <- c("infl", "unemp", "ffr")      # column order = Cholesky ordering used below
m <- VAR(y, p = 4, type = "const")            # VAR(4) with a constant

#| **Forecast error variance decomposition.** `fevd()` asks: when the VAR's *h*-quarter-ahead forecast of a variable misses, what share of that miss (its variance) comes from each orthogonalized shock? Each row sums to 1. It uses the same Cholesky ordering as `irf()`.
fe <- fevd(m, n.ahead = 20)                   # shares for horizons 1 to 20 quarters (5 years)
round(fe$unemp[c(1, 4, 8, 12, 20), ], 3)      # unemployment: rows = selected horizons, columns = shocks

#| **Read it as a story about horizons.** One quarter ahead, unemployment surprises are almost entirely unemployment's own shocks (98%). Five years out, inflation shocks account for about half, and funds-rate shocks for under a tenth. Policy *surprises* are a small source of fluctuations; most of what the Fed does is a predictable reaction to the economy, which the VAR files under the other shocks.
viz_custom("ch09-fevd", h = 1:20, response = "Unemployment",   # stacked shares chart, one band per shock
  shares = list(Inflation = fe$unemp[, "infl"], Unemployment = fe$unemp[, "unemp"], `Fed funds` = fe$unemp[, "ffr"]),
  title = "Five years out, inflation shocks explain half of unemployment's forecast errors",
  subtitle = "Share of the h-quarter-ahead forecast error variance of unemployment, by shock", source = .course_src())

#| **The funds rate itself.** At long horizons, most of the variation in the funds rate comes from inflation and unemployment shocks. That is the VAR's way of saying the Fed mostly *responds* to the economy.
# sapply runs the function on each variable's table; take row 20 (horizon 20), in %; t() flips rows/columns
tab <- t(sapply(fe, function(x) 100 * x[20, ]))
tab <- data.frame(Forecast = c("Inflation", "Unemployment", "Fed funds"),   # one row per forecast variable
                  `Inflation shock` = tab[, "infl"], `Unemployment shock` = tab[, "unemp"],
                  # check.names = FALSE keeps spaces in names
                  `Fed funds shock` = tab[, "ffr"], check.names = FALSE)
viz_table(tab, digits = 1, title = "Percent of 20-quarter-ahead forecast error variance, by shock")
