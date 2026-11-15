#| **Load the data.** `fred()` returns a pandas `Series` indexed by date. `RSXFSN` is U.S. retail sales ($ millions, monthly, not seasonally adjusted).
retail = fred("RSXFSN", start=2012)           # monthly U.S. retail sales ($ millions, not seasonally adjusted) from Jan 2012

#| **Look before you model.** Hover over the chart. Notice the December spikes and the COVID crash.
viz_ts(retail, title="U.S. retail sales ($ millions)")   # interactive line chart of the raw data

#| **Fit a seasonal ARIMA** on log sales with statsmodels. Python has no built-in `auto.arima()`, so we fix the order at (1,1,1)(0,1,1,12), a close cousin of the classic "airline" model for monthly data. The R tab lets `auto.arima()` choose, so its model and numbers differ a little from this one.
from statsmodels.tsa.statespace.sarimax import SARIMAX   # seasonal ARIMA model class
# fit on log sales: (p,d,q) = (1,1,1), seasonal (P,D,Q,period) = (0,1,1,12); disp=False hides fitting messages
fit = SARIMAX(np.log(retail), order=(1, 1, 1), seasonal_order=(0, 1, 1, 12)).fit(disp=False)

#| **Forecast 24 months** and get 80% and 95% intervals, then undo the log with `np.exp`.
pred = fit.get_forecast(24)                   # forecast 24 months ahead (still in logs)
ci80, ci95 = pred.conf_int(alpha=0.20), pred.conf_int(alpha=0.05)   # interval tables: alpha 0.20 -> 80%, 0.05 -> 95%
mean = np.exp(pred.predicted_mean)            # point forecasts, converted back to dollars

#| **Show it.** The fan widens as uncertainty compounds.
viz_forecast(retail["2018":], mean,           # history from 2018 on, plus the point forecasts
             lower=[np.exp(ci80.iloc[:, 0]), np.exp(ci95.iloc[:, 0])],   # .iloc[:, 0] = first column: lower bounds
             upper=[np.exp(ci80.iloc[:, 1]), np.exp(ci95.iloc[:, 1])],   # .iloc[:, 1] = second column: upper bounds
             levels=("80%", "95%"), method="Seasonal ARIMA",
             title="U.S. retail sales: 24-month forecast")
