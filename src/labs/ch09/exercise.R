library(vars)                           # VAR estimation, lag selection, Granger tests
q <- function(id) fred(id, to = "quarter")   # helper: FRED series as quarterly averages
spread <- q("GS10") - q("TB3MS")        # term spread, percentage points
unemp  <- q("UNRATE")                   # unemployment rate, %, SA
# common quarters only, 1960Q1 to 2000Q4
z <- window(na.omit(ts.intersect(spread, unemp)), start = c(1960, 1), end = c(2000, 4))
colnames(z) <- c("spread", "unemp")     # short column names

# 1. Let the information criteria choose the lag length (use BIC, called "SC(n)")
# blank: the name of the BIC entry in the $selection vector
p <- VARselect(z, lag.max = 8, type = "const")$selection[["______"]]

# 2. Fit a two-variable VAR with that many lags
m <- VAR(z, p = p, type = "const")

# 3. Does the spread Granger-cause unemployment? Store the p-value.
# blank: the column name of the variable whose past we test
pval <- causality(m, cause = "______")$Granger$p.value
pval                                    # small p-value = its past helps predict the other variable
