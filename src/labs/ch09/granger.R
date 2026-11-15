#| **Same data, same VAR(4)** as the first lab (each lab starts fresh).
library(vars)
q <- function(id) fred(id, to = "quarter")
y <- na.omit(ts.intersect(400 * diff(log(q("CPIAUCSL"))), q("UNRATE"), q("FEDFUNDS")))
y <- window(y, start = c(1960, 1), end = c(2000, 4))
colnames(y) <- c("infl", "unemp", "ffr")
m <- VAR(y, p = 4, type = "const")

#| **Does the funds rate help predict the other two?** `causality(m, cause = "ffr")` runs an F-test of the null *"all four lags of `ffr` have zero coefficients in the `infl` and `unemp` equations"*. A small p-value means past rates contain information about future inflation and unemployment beyond what those two series' own pasts already contain.
gc <- causality(m, cause = "ffr")$Granger
gc

#| **Test every variable in turn** and collect the p-values in a table. Read each row as "does the past of X help forecast the other two?"
tests <- sapply(colnames(y), function(v) {
  g <- causality(m, cause = v)$Granger
  c(F = unname(g$statistic), df1 = unname(g$parameter[1]), p.value = unname(g$p.value))
})
viz_table(t(tests), digits = 7, title = "Every variable Granger-causes the others in 1960–2000")

#| **Same question, different decades.** A pairwise test in a two-variable VAR: does the **term spread** (10-year minus 3-month Treasury yield) help predict unemployment? Compare the 1960–2000 sample with 1985–2019. Predictive relationships are not laws of nature; they can fade.
spread <- q("GS10") - q("TB3MS")
z <- na.omit(ts.intersect(spread, unemp = q("UNRATE")))
colnames(z) <- c("spread", "unemp")
p_early <- causality(VAR(window(z, 1960, c(2000, 4)), p = 4), cause = "spread")$Granger$p.value
p_late  <- causality(VAR(window(z, 1985, c(2019, 4)), p = 4), cause = "spread")$Granger$p.value
round(c(`1960-2000` = p_early, `1985-2019` = p_late), 4)
