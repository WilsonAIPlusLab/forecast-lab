#| **Load the data.** `fred()` reads one of the bundled FRED series and returns an R *time series* (`ts`) object. `RSXFSN` is U.S. retail sales in millions of dollars, monthly, **not** seasonally adjusted.
retail <- fred("RSXFSN", start = 2012)        # monthly U.S. retail sales ($ millions, not seasonally adjusted) from Jan 2012

#| **Look before you model.** `viz_ts()` draws an interactive chart. Hover over it to read values. Notice the December spikes every year and the COVID crash in April 2020.
viz_ts(retail, title = "U.S. retail sales ($ millions)")   # interactive line chart of the raw data

#| **Load the toolkit.** The `forecast` package by Rob Hyndman is the standard forecasting library in R. The first time, the browser downloads it (a few seconds).
library(forecast)                             # Hyndman's forecasting package

#| **Fit a model automatically.** `auto.arima()` searches many ARIMA models and keeps the one with the lowest AICc. `lambda = 0` means "model the log", so growth is proportional, and forecasts are transformed back to dollars for us.
fit <- auto.arima(retail, lambda = 0)         # pick the best ARIMA model; lambda = 0 = work on log sales
fit                                           # print the chosen model and its coefficients

#| **Forecast 24 months ahead.** `forecast()` returns point forecasts **plus** 80% and 95% prediction intervals.
fc <- forecast(fit, h = 24)                   # forecast 24 months ahead, with 80% and 95% intervals

#| **Show it.** The shaded fan widens over time: uncertainty compounds the further ahead we look. Hover over the forecast to read the interval.
# fan chart: history from 2018 on, then the forecast and its shaded intervals
viz_forecast(fc, from = 2018, title = "U.S. retail sales: 24-month forecast", subtitle = "Seasonal ARIMA on log sales, 80% and 95% intervals")
