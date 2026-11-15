#| **Load and split in time.** Train through Dec 2022, test from Jan 2023 onward. The test set must come *after* the training set.
retail = fred("RSXFSN", start=2010)           # monthly U.S. retail sales ($ millions, not seasonally adjusted) from Jan 2010
train = retail[:"2022-12"]                    # training set: everything up to December 2022
test = retail["2023-01":]                     # test set: January 2023 onward, hidden from the models
h = len(test)                                 # forecast horizon = number of test months

#| **Four benchmarks by hand.** Each is a single line of pandas, which shows how simple they are. Seasonal naive repeats the last 12 training months; drift extends the line from the first to the last training value.
idx = test.index                              # the test dates: every forecast is labelled with them
f_mean   = pd.Series(train.mean(), index=idx)   # forecast = average of all training months
f_naive  = pd.Series(train.iloc[-1], index=idx)   # forecast = last observed month, repeated (.iloc[-1] = last row)
# forecast = same month one year earlier: i % 12 cycles 0..11 through the last 12 training months
f_snaive = pd.Series([train.iloc[-12 + (i % 12)] for i in range(h)], index=idx)
slope    = (train.iloc[-1] - train.iloc[0]) / (len(train) - 1)   # average change per month, first to last point
# forecast = straight line from first to last point
f_drift  = pd.Series(train.iloc[-1] + slope * np.arange(1, h + 1), index=idx)

#| **Plot against the truth** (gold, dashed). Seasonal naive copies the December peaks and January dips; the other three cut straight through them.
viz_compare(history=train["2019":], actual=test, Mean=f_mean, Naive=f_naive,   # show 2019+ history and the real test data
            **{"Seasonal naive": f_snaive}, Drift=f_drift,   # ** lets a name contain a space
            title="Only seasonal naive tracks the December peaks and January dips")

#| **Score them.** MASE divides MAE by the in-sample MAE of a seasonal naive forecast, so a value below 1 means "better than the seasonal naive method did on the training data".
scale = (train - train.shift(12)).abs().mean()   # MASE scale: in-sample MAE of seasonal naive on the training data
def score(f):                                 # five error metrics for one forecast on the test set
    e = test - f                              # forecast errors: actual minus forecast
    return {"ME": e.mean(), "MAE": e.abs().mean(), "RMSE": np.sqrt((e**2).mean()),
            "MAPE": 100 * (e / test).abs().mean(), "MASE": e.abs().mean() / scale}
# one column per method, then .T (transpose) to get one row per method
scores = pd.DataFrame({k: score(v) for k, v in
                       {"Mean": f_mean, "Naive": f_naive, "Seasonal naive": f_snaive, "Drift": f_drift}.items()}).T
print(scores.round(2))                        # print the table: lower is better (except ME, which should be near 0)

#| **The scorecard.** Green marks the best value for each metric. The numbers match R's `accuracy()` exactly: seasonal naive wins every metric, with an MAE of about 25 billion dollars a month and a MASE of about 1.04.
viz_table(scores, highlight=["MAE", "RMSE", "MAPE", "MASE"], digits=2,   # green = best value in each column
          title="Seasonal naive wins the retail scorecard, 2023 onward")
