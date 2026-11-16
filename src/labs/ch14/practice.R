#| **Step 1: choose your series and write the data note.** Change the six settings to any monthly series in the table above. The defaults are **U.S. light vehicle sales** (`TOTALNSA`): thousands of new cars and light trucks sold each month, **not seasonally adjusted**. `scale` converts FRED's units into the units you will report (1,000 turns $ millions into $ billions; use 1 to keep them). Everything below adapts to your choice.
library(forecast)                                # ets(), snaive(), rwf(), forecast()
id     <- "TOTALNSA"                             # FRED ID of your series
name   <- "U.S. light vehicle sales"             # what to call it in the summary
adj    <- "not seasonally adjusted"              # copy SA or NSA from the data catalog
scale  <- 1                                      # FRED units / scale = units you report
units  <- "thousand vehicles"                    # report units in words ("billion dollars", "percent", ...)
digits <- 0                                      # decimals to show (2 for rates and for payrolls in millions)
y <- fred(id, start = 2010) / scale              # monthly data from January 2010, in report units
num <- function(v) formatC(v, format = "f", digits = digits, big.mark = ",")   # e.g. 1,234.5
cat(sprintf("Data note: %s (FRED %s), %s, %s, monthly, %s to %s, %d months.\n", name, id, units, adj,
            format(as.Date(ts_dates(y)[1]), "%b %Y"), format(as.Date(tail(ts_dates(y), 1)), "%b %Y"), length(y)))

#| **Step 2: plot it and check your label.** Look for trend, seasonality, outliers (2020!) and breaks before any model. Then check the SA/NSA label against the data with the multiplicative decomposition from [Chapter 2](/chapters/decomposition/), run on 2010 to 2019 so the 2020 shock cannot distort it: `figure` holds the 12 seasonal factors (1.10 = that month runs 10% above the trend). A big gap between the highest and lowest month means strong seasonality, which you should see only in **NSA** data. In SA data the gap is close to zero.
viz_ts(y, ylab = units, title = sprintf("%s since 2010 (%s)", name, adj))   # look before you model
pre2020 <- window(y, end = c(2019, 12))         # 2010-2019 only: 2020 would distort the factors
sf <- decompose(pre2020, type = "multiplicative")$figure   # 12 seasonal factors, January to December
names(sf) <- month.abb                           # label them Jan ... Dec
round(100 * (sf - 1), 1)                         # each month's typical % gap from the trend
sprintf("Seasonal swing: %s is typically %.0f%% above trend, %s %.0f%% below.",   # sizes the seasonality
        month.name[which.max(sf)], 100 * (max(sf) - 1), month.name[which.min(sf)], 100 * (1 - min(sf)))

#| **Step 3: benchmark first, then one model, on an honest test.** At 8 forecast origins (one every 6 months over the last four years) every method is re-fitted on the data up to that origin and forecasts the next 12 months. The ETS form is chosen once, on data **before the first origin**, so the test never peeks. The scorecard reports MAE in your units and the bias (positive = forecasts too low).
h <- 12                                          # forecast 1 to 12 months ahead
origins <- seq(length(y) - 48, length(y) - 6, by = 6)   # 8 origins over the last four years
form <- ets(window(y, end = time(y)[origins[1]]))       # ETS form chosen on early data only
methods <- list(`Seasonal naive` = function(x) snaive(x, h = h)$mean,          # same month last year
                Naive = function(x) rwf(x, h = h)$mean,                        # last value carried forward
                Drift = function(x) rwf(x, h = h, drift = TRUE)$mean,          # straight-line trend
                # the chosen ETS form (letters such as "MAM", plus damped or not), re-estimated at each origin
                ETS = function(x) forecast(ets(x, model = paste(form$components[1:3], collapse = ""),
                                               damped = form$components[4] == "TRUE"), h = h)$mean)
# for each method and origin: actual minus forecast, one row per origin, one column per horizon
errs <- lapply(methods, function(fun) t(sapply(origins, function(o) y[o + 1:h] - as.numeric(fun(window(y, end = time(y)[o]))))))
score <- data.frame(MAE = sapply(errs, function(e) mean(abs(e), na.rm = TRUE)),        # typical miss, all horizons
                    `MAE 1 month` = sapply(errs, function(e) mean(abs(e[, 1]))),       # typical miss, 1 month ahead
                    Bias = sapply(errs, function(e) mean(e, na.rm = TRUE)), check.names = FALSE)
best <- rownames(score)[which.min(score$MAE)]   # the method with the lowest MAE
viz_table(score, highlight = c("MAE", "MAE 1 month"), digits = 2,
          title = sprintf("%s wins the honest test (%s; ETS form %s)", best, units, form$method))

#| **Step 4: the forecast and an 80% range you can defend.** The best method is re-fitted on all the data. Its 80% range for 12 months ahead adds the 10th and 90th percentiles of the errors it made 12 months ahead at past origins (only 8 errors, so the edges are rough). Then the forecast is compared **like with like**: with the same month a year earlier, which is safe for SA and NSA data alike.
fc <- methods[[best]](y)                         # final forecasts from all the data
point <- as.numeric(fc[h])                       # the forecast 12 months out
q <- quantile(errs[[best]][, h], c(0.10, 0.90), na.rm = TRUE)   # past 12-month-ahead errors
lo80 <- point + q[1]; hi80 <- point + q[2]       # forecast + 10th / 90th-percentile error
same_month <- as.numeric(tail(y, 12)[h])         # actual value 12 months before the target month
rate <- grepl("percent", units)                  # rates are compared in percentage points, not percent
miss_units <- if (rate) "percentage points" else units   # a miss in a rate is measured in points
yoy <- if (rate) point - same_month else 100 * (point / same_month - 1)   # change on the same month a year earlier
if (point < lo80 || point > hi80)                # past errors all on one side: say so as the key risk
  cat("Note: the forecast lies outside its own 80% range, because this method's past errors were almost all on one side (bias). Make that the key risk.
")
when <- format(as.Date(ts_dates(fc)[h]), "%B %Y")   # target month in words

#| **Step 5: the executive summary.** Bottom line first: a number with units and a date, a like-with-like comparison, a range, and a track record against the benchmark in your reader's units. Add the key risk and the trigger yourself, in your own words: they need judgement that code cannot supply.
vs_bench <- 100 * (1 - score[best, "MAE"] / score["Seasonal naive", "MAE"])   # % smaller miss than seasonal naive
track <- if (best == "Seasonal naive") {         # the benchmark won: say so plainly
  sprintf("no method beat the simple rule of using the same month last year, whose typical miss was %s %s one month ahead",
          num(score[best, "MAE 1 month"]), miss_units)
} else {                                         # a method won: compare it with the benchmark
  sprintf("the most accurate method was %s: its typical miss was %s %s one month ahead, and its average miss was %.0f%% %s than using the same month last year",
          best, num(score[best, "MAE 1 month"]), miss_units, abs(vs_bench), ifelse(vs_bench >= 0, "smaller", "larger"))
}
summary_text <- sprintf(
  "We expect %s (%s) to be about %s %s in %s, %s %s the same month a year earlier. Our 80%% range is %s to %s %s. Over 8 forecast origins in the past four years, %s.",
  name, adj, num(point), units, when, ifelse(rate, sprintf("%.2f percentage points", abs(yoy)), sprintf("%.1f%%", abs(yoy))),
  ifelse(yoy >= 0, "above", "below"),            # bottom line + like-with-like comparison
  num(lo80), num(hi80), units, track)            # range and track record
cat(strwrap(summary_text, 90), sep = "\n")       # print, wrapped at 90 characters per line
