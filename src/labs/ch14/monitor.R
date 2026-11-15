#| **Deploy a model.** We pretend it is January 2019. We fit a damped-trend exponential smoothing model, ETS(A,Ad,N), to U.S. e-commerce sales (FRED `MRTSSM4541USS`, **seasonally adjusted**, $ billions) using data through December 2018, then "ship" it.
library(forecast)
y <- fred("MRTSSM4541USS", start = 2010) / 1000
fit <- ets(window(y, end = c(2018, 12)), model = "AAN", damped = TRUE)

#| **Run it in production.** Passing `model = fit` re-runs the same model on the full series *without* re-estimating anything, so `fitted(live)` holds the one-month-ahead forecasts the deployed model would have issued each month. The errors from January 2019 on are what a monitoring dashboard would have seen.
live <- ets(y, model = fit, use.initial.values = TRUE)
err <- window(y - fitted(live), start = c(2019, 1))

#| **The tracking signal**: the running sum of errors divided by the running mean absolute error (MAD). If errors are random, positives and negatives cancel and the signal hovers near zero. A common rule raises an alarm beyond ±4.
signal <- ts(cumsum(err) / (cumsum(abs(err)) / seq_along(err)), start = start(err), frequency = 12)
alarm <- which(abs(signal) > 4)[1]
viz_ts(`Tracking signal` = signal, ylab = "running sum of errors / MAD",
       title = "The deployed model's errors pile up on one side within months")
sprintf("First alarm: %s, tracking signal %.1f. Mean error since deployment: %+.2f $ billions.",
        format(as.Date(ts_dates(signal)[alarm]), "%B %Y"), signal[alarm], mean(err))

#| **A reproducibility stamp.** Put this at the bottom of every forecast you ship: the software versions and the last data point used. Anyone can then rerun the script and get the same numbers, or see exactly why they differ.
c(R = R.version.string, forecast = as.character(packageVersion("forecast")),
  series = "MRTSSM4541USS", data_through = tail(ts_dates(y), 1))
