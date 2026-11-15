#| **Build three quarterly series.** `fred(..., to = "quarter")` averages the monthly data within each quarter. Inflation is the annualized quarterly change in the CPI (SA): `400 * diff(log(cpi))` is the percent change at an annual rate. Unemployment (SA) and the federal funds rate are in percent. This is the system Stock and Watson (2001) used to explain VARs, with CPI standing in for their GDP price index.
library(vars)                                 # VAR estimation, lag selection, IRFs, FEVD
q <- function(id) fred(id, to = "quarter")    # helper: download a FRED series as quarterly averages
infl  <- 400 * diff(log(q("CPIAUCSL")))       # CPI inflation, % at an annual rate (log change x 4 quarters x 100)
unemp <- q("UNRATE")                          # unemployment rate, %
ffr   <- q("FEDFUNDS")                        # federal funds (policy) interest rate, %

#| **Line them up and pick the sample.** `ts.intersect()` keeps only the quarters where all three exist; `window()` keeps 1960Q1 to 2000Q4, the Stock–Watson sample. Stopping in 2000 also keeps the 2009–2015 period out: with the funds rate stuck at zero, a linear VAR would struggle there.
y <- na.omit(ts.intersect(infl, unemp, ffr))  # one multi-column ts; keep quarters where all three exist
y <- window(y, start = c(1960, 1), end = c(2000, 4))   # window() cuts a ts by date: 1960Q1 to 2000Q4
colnames(y) <- c("infl", "unemp", "ffr")      # short column names used in every later step
dim(y)                                        # rows = quarters, columns = variables

#| **Look before you model.** Three panels: the 1970s inflation, the Volcker rate spike of 1979–81, and unemployment peaks in every recession (shaded). A VAR will try to describe how each of these lines feeds into the others.
# y[, "infl"] means "all rows, the infl column"; one panel per series, recessions shaded
viz_ts(Inflation = y[, "infl"], Unemployment = y[, "unemp"], `Fed funds` = y[, "ffr"],
       facet = TRUE, recessions = TRUE, ylab = "% (inflation annualized)",   # facet = separate panels
       title = "The Volcker spike: rates, inflation and jobs move together")

#| **How many lags?** `VARselect()` fits VAR(1) through VAR(8) and reports the lag each information criterion prefers. AIC tends to choose more lags, BIC (called `SC` here) fewer. All four agree on 3 here. We will use **4**, as Stock and Watson did (one full year of quarters); the results barely change.
# best lag by AIC, HQ, SC (BIC), FPE; "const" = include an intercept
VARselect(y, lag.max = 8, type = "const")$selection

#| **Fit the VAR.** One line, but it runs three regressions: each variable on four lags of *all three* variables plus a constant. That is 3 × 4 + 1 = 13 coefficients per equation and 39 in total, estimated from 160 quarters.
m <- VAR(y, p = 4, type = "const")            # VAR(4): p = 4 lags (one year of quarters) plus a constant
round(coef(m)$unemp, 3)[1:6, ]                # first 6 rows of the unemployment equation: estimate, s.e., t, p

#| **Is it stable?** A VAR is stable (stationary) if all eigenvalues of its companion matrix, `roots()`, are below 1. Ours peak at about 0.95: very persistent, but shocks eventually die out. Then `summary(m)` would print the full output; here we print just the correlation of the residuals, which will matter a lot later.
round(roots(m)[1:3], 3)                       # three largest root moduli; all below 1 means stable
round(cor(residuals(m)), 2)                   # how correlated the three equations' surprises are
