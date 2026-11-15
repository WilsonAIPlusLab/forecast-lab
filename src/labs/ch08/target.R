#| **Load two monthly series from FRED.** `USREC` is the NBER recession indicator: 1 in every month the economy was in recession, 0 otherwise. The **term spread** is the 10-year Treasury yield minus the 3-month bill rate, both monthly averages in percent, so the spread is in percentage points. When it is negative, the yield curve is *inverted*. We start in 1959, as the New York Fed does.
rec    <- fred("USREC", start = 1959)
spread <- fred("GS10", start = 1959) - fred("TB3MS", start = 1959)
X <- ts.intersect(rec, spread)
d <- data.frame(date = as.Date(ts_dates(X)), spread = as.numeric(X[, "spread"]), rec = as.numeric(X[, "rec"]))

#| **Look before you model.** Grey bars are NBER recessions. Watch the spread dip below zero a year or so before most of them, and notice the long inversion from late 2022 to late 2024 that was *not* followed by a recession (so far).
viz_ts(`10y minus 3m spread` = X[, "spread"], recessions = TRUE, ylab = "pct. points",
       title = "The spread dips below zero ahead of most recessions",
       subtitle = "Monthly average 10-year Treasury yield minus 3-month bill rate; grey = NBER recession")

#| **Build the forward-looking target.** For each month *t*, the question is "will month *t* + 12 be a recession month?" So the target is the recession indicator **shifted 12 months back**: drop the first 12 values and pad the end with `NA`.
#| - This is the New York Fed's definition. It puts *today's* spread next to the economy's state *a year from now*.
#| - The last 12 rows have no answer yet, so they are `NA`. Those are the months we actually want to forecast.
d$rec_ahead <- c(d$rec[-(1:12)], rep(NA, 12))
tail(d, 14)

#| **Check the shift by eye.** Pick a recession start: December 2007 was the peak, so January 2008 is the first recession month in `USREC`. Twelve months earlier, January 2007, should have `rec_ahead = 1` while `rec` is still 0.
d[d$date >= as.Date("2006-11-01") & d$date <= as.Date("2007-03-01"), ]

#| **Try the simplest model: a linear probability model (LPM).** Regress the 0/1 target on the spread with ordinary `lm()`. The fitted values are meant to be probabilities. `lm()` drops the `NA` rows automatically.
lpm <- lm(rec_ahead ~ spread, data = d)
coef(lpm)

#| **The LPM's flaw: impossible probabilities.** A straight line has no floor or ceiling. With a steep yield curve it predicts a *negative* chance of recession, which is meaningless. Count the months.
p_lpm <- predict(lpm, newdata = d)
range(p_lpm)
sum(p_lpm < 0)
viz_ts(`LPM "probability"` = ts(p_lpm, start = c(1959, 1), frequency = 12), recessions = TRUE,
       title = sprintf("A straight line predicts a negative chance of recession in %d months", sum(p_lpm < 0)),
       subtitle = "Fitted values from lm(rec_ahead ~ spread), dated at the forecast month t")
