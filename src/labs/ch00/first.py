#| **Load the data.** `fred()` returns a pandas `Series` indexed by date. `RSXFSN` is U.S. retail sales ($ millions, monthly, not seasonally adjusted).
retail = fred("RSXFSN", start=2012)

#| **Look before you model.** Hover over the chart. Notice the December spikes and the COVID crash.
viz_ts(retail, title="U.S. retail sales ($ millions)")

#| **Fit a seasonal ARIMA** on log sales with statsmodels. Python has no built-in `auto.arima()`, so we fix the order at (1,1,1)(0,1,1,12), a close cousin of the classic "airline" model for monthly data. The R tab lets `auto.arima()` choose, so its model and numbers differ a little from this one.
from statsmodels.tsa.statespace.sarimax import SARIMAX
fit = SARIMAX(np.log(retail), order=(1, 1, 1), seasonal_order=(0, 1, 1, 12)).fit(disp=False)

#| **Forecast 24 months** and get 80% and 95% intervals, then undo the log with `np.exp`.
pred = fit.get_forecast(24)
ci80, ci95 = pred.conf_int(alpha=0.20), pred.conf_int(alpha=0.05)
mean = np.exp(pred.predicted_mean)

#| **Show it.** The fan widens as uncertainty compounds.
viz_forecast(retail["2018":], mean,
             lower=[np.exp(ci80.iloc[:, 0]), np.exp(ci95.iloc[:, 0])],
             upper=[np.exp(ci80.iloc[:, 1]), np.exp(ci95.iloc[:, 1])],
             levels=("80%", "95%"), method="Seasonal ARIMA",
             title="U.S. retail sales: 24-month forecast")
