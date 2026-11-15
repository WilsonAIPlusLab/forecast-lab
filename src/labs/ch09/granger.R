#| **Same data, same VAR(4)** as the first lab (each lab starts fresh).
library(vars)                                 # VAR estimation and Granger tests
q <- function(id) fred(id, to = "quarter")    # helper: FRED series as quarterly averages
# inflation (annualized %), unemployment, funds rate; keep quarters where all three exist
y <- na.omit(ts.intersect(400 * diff(log(q("CPIAUCSL"))), q("UNRATE"), q("FEDFUNDS")))
y <- window(y, start = c(1960, 1), end = c(2000, 4))   # Stock–Watson sample, 1960Q1 to 2000Q4
colnames(y) <- c("infl", "unemp", "ffr")      # short column names
m <- VAR(y, p = 4, type = "const")            # VAR(4) with a constant

#| **Does the funds rate help predict the other two?** `causality(m, cause = "ffr")` runs an F-test of the null *"all four lags of `ffr` have zero coefficients in the `infl` and `unemp` equations"*. A small p-value means past rates contain information about future inflation and unemployment beyond what those two series' own pasts already contain.
gc <- causality(m, cause = "ffr")$Granger     # Granger-causality F-test for the funds rate
gc                                            # print F statistic, degrees of freedom, p-value

#| **Test every variable in turn** and collect the p-values in a table. Read each row as "does the past of X help forecast the other two?"
# sapply loops over the variable names and stacks each result as a column
tests <- sapply(colnames(y), function(v) {
  g <- causality(m, cause = v)$Granger        # does the past of v help predict the other two?
  c(F = unname(g$statistic), df1 = unname(g$parameter[1]), p.value = unname(g$p.value))   # unname drops labels
})
# t() = one row per variable
viz_table(t(tests), digits = 7, title = "Every variable Granger-causes the others in 1960–2000")

#| **Same question, different decades.** A pairwise test in a two-variable VAR: does the **term spread** (10-year minus 3-month Treasury yield) help predict unemployment? Compare the 1960–2000 sample with 1985–2019. Predictive relationships are not laws of nature; they can fade.
spread <- q("GS10") - q("TB3MS")              # term spread, percentage points
z <- na.omit(ts.intersect(spread, unemp = q("UNRATE")))   # two-variable system, common quarters only
colnames(z) <- c("spread", "unemp")           # short column names
# fit a VAR(4) on each sub-sample and keep the p-value of "spread Granger-causes unemp"
p_early <- causality(VAR(window(z, 1960, c(2000, 4)), p = 4), cause = "spread")$Granger$p.value
p_late  <- causality(VAR(window(z, 1985, c(2019, 4)), p = 4), cause = "spread")$Granger$p.value
round(c(`1960-2000` = p_early, `1985-2019` = p_late), 4)   # small p = spread helps predict unemployment
