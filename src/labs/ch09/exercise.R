library(vars)
q <- function(id) fred(id, to = "quarter")
spread <- q("GS10") - q("TB3MS")        # term spread, percentage points
unemp  <- q("UNRATE")                   # unemployment rate, %, SA
z <- window(na.omit(ts.intersect(spread, unemp)), start = c(1960, 1), end = c(2000, 4))
colnames(z) <- c("spread", "unemp")

# 1. Let the information criteria choose the lag length (use BIC, called "SC(n)")
p <- VARselect(z, lag.max = 8, type = "const")$selection[["______"]]

# 2. Fit a two-variable VAR with that many lags
m <- VAR(z, p = p, type = "const")

# 3. Does the spread Granger-cause unemployment? Store the p-value.
pval <- causality(m, cause = "______")$Granger$p.value
pval
