# Generates src/components/ch06/urdata.json for the "unit-root verdict" explorable.
# Run from site/:  Rscript src/labs/ch06/make_data.R
# For each real series: ADF and KPSS p-values (tseries defaults, as in the chapter's labs),
# ndiffs(), the lag-1 autocorrelation and the standard deviation, in levels and after one difference.
library(jsonlite); library(tseries); library(forecast)
setwd("public")
source("r/course.R")
g <- function(id, ...) fred(id, quiet = TRUE, ...)
S <- list(
  lpce   = list(x = log(g("PCEPILFE", start = c(2000, 1))), label = "Core PCE prices (log)", id = "PCEPILFE", start = "2000-01-01", end = NULL, tf = "log", unit = "log index", dunit = "monthly log change"),
  unrate = list(x = g("UNRATE", start = 1990, end = c(2019, 12)), label = "Unemployment rate", id = "UNRATE", start = "1990-01-01", end = "2019-12-01", tf = "none", unit = "%", dunit = "monthly change, pp"),
  houst  = list(x = log(g("HOUST", start = 1990, end = c(2019, 12))), label = "Housing starts (log)", id = "HOUST", start = "1990-01-01", end = "2019-12-01", tf = "log", unit = "log thousands of units, SAAR", dunit = "monthly log change"),
  sent   = list(x = g("UMCSENT", start = 1990, end = c(2019, 12)), label = "Consumer sentiment", id = "UMCSENT", start = "1990-01-01", end = "2019-12-01", tf = "none", unit = "index, 1966:Q1 = 100", dunit = "monthly change, points"),
  spread = list(x = g("T10Y3M", start = 1990, to = "month"), label = "Yield spread (10y − 3m)", id = "T10Y3M", to = "month", start = "1990-01-01", end = NULL, tf = "none", unit = "percentage points", dunit = "monthly change, pp"),
  pay    = list(x = log(g("PAYEMS", start = 1990, end = c(2019, 12))), label = "Payroll jobs (log)", id = "PAYEMS", start = "1990-01-01", end = "2019-12-01", tf = "log", unit = "log thousands", dunit = "monthly log change")
)
tst <- function(x) { x <- na.omit(x)
  list(adf = suppressWarnings(adf.test(x)$p.value), kpss = suppressWarnings(kpss.test(x)$p.value), nd = ndiffs(x),
       r1 = acf(x, lag.max = 1, plot = FALSE)$acf[2], sd = sd(x), n = length(x)) }
out <- lapply(names(S), function(k) { s <- S[[k]]
  list(key = k, label = s$label, id = s$id, to = s$to, start = s$start, end = s$end, tf = s$tf, unit = s$unit, dunit = s$dunit,
       level = lapply(tst(s$x), signif, 4), diff = lapply(tst(diff(s$x)), signif, 4)) })
write_json(out, "../src/components/ch06/urdata.json", auto_unbox = TRUE, digits = NA, null = "null")
cat("wrote urdata.json\n")
