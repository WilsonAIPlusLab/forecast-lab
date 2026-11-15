#| **Same table as before**: retail sales growth (% per month, NSA) with two lags, the seasonal lag and the month (as an integer for scikit-learn). Train through 2022.
from sklearn.ensemble import RandomForestRegressor
retail = fred("RSXFSN", start=2010)           # monthly retail sales, $ millions, not seasonally adjusted
train_y, test_y = retail[:"2022-12"], retail["2023-01":]   # levels: train through Dec 2022, test from Jan 2023
def make_features(g):
    # target g, lags 1, 2 and 12 (.shift(k) moves values down k rows), calendar month 1-12
    return pd.DataFrame({"g": g, "g1": g.shift(1), "g2": g.shift(2), "g12": g.shift(12), "month": g.index.month})
train = make_features(100 * np.log(train_y).diff()).dropna()   # growth feature table, incomplete rows dropped
X_cols = ["g1", "g2", "g12", "month"]         # the feature columns

#| **A random forest of 100 trees** (R uses 300; scikit-learn's per-call overhead makes 100 the kinder choice in the browser). Bootstrap rows, `max_features=2` features per split (R's `mtry`), no splitting of nodes with fewer than 5 months (close to R's `nodesize = 5`), and the average of all trees as the forecast. `oob_score=True` keeps the out-of-bag predictions.
rf = RandomForestRegressor(n_estimators=100, max_features=2, min_samples_split=5, oob_score=True, random_state=1)   # random_state = seed
rf.fit(train[X_cols], train["g"])             # learn growth g from the 4 features

#| **Out-of-bag error**: each row scored only by the trees that never saw it. RMSE in percentage points of monthly growth.
print(round(float(np.sqrt(np.mean((train["g"] - rf.oob_prediction_) ** 2))), 2))   # OOB RMSE

#| **Which features matter?** scikit-learn's built-in `feature_importances_` is *impurity* importance: how much each feature's splits reduced squared error, averaged over trees. (R's lab shows *permutation* importance instead; both rank seasonal features highly here.)
imp = pd.Series(rf.feature_importances_, index=X_cols)   # shares that sum to 1
print(imp.round(3))
viz_bars(imp, title="Seasonality drives the forest's retail forecasts",
         subtitle="Impurity importance: share of the total error reduction from each feature's splits", xlab="share of error reduction")

#| **Recursive forecast back to dollars**: build the next month's feature row, predict its growth, compound, append, repeat.
def forecast_rf(model, y, h):
    # running lists: levels ($ millions), growth (%, aligned with levels), calendar month of each row
    lev = list(y.astype(float)); g = [np.nan] + list(100 * np.diff(np.log(lev))); mon = list(y.index.month)
    for _ in range(h):                        # one pass per month ahead
        m = mon[-1] % 12 + 1                  # the month we are about to forecast ([-1] = last item)
        X = pd.DataFrame({"g1": [g[-1]], "g2": [g[-2]], "g12": [g[-12]], "month": [m]})   # its one feature row
        g_hat = float(model.predict(X)[0])    # forecast growth for that month
        lev.append(lev[-1] * np.exp(g_hat / 100)); g.append(g_hat); mon.append(m)   # append as if it were data
    # last h levels, dated monthly ("MS" = month start) from the month after y ends
    return pd.Series(lev[-h:], index=pd.date_range(y.index[-1] + pd.offsets.MonthBegin(1), periods=h, freq="MS"))

fc_rf = forecast_rf(rf, train_y, len(test_y))   # forecast every test month

#| **Check it against reality.** MAE in $ millions. Expect a clearly worse number than the R tab (about 23,000 vs 13,000). The two libraries differ in details: here `month` is an integer, so a split can only cut it into ranges (R treats it as a category), and the forest has 100 trees instead of 300. A 45-month recursive forecast then amplifies small differences. Try `random_state=2` or `3` above: the MAE swings from about 19,000 to 30,000. Implementation details and seeds matter in machine learning, which is why the bake-off checks several seeds.
viz_compare(history=train_y["2019":], actual=test_y, **{"Random forest": fc_rf},   # ** unpacks a dict into named arguments
            title="The forest learned retail's seasonal rhythm from lag features")
print(round(float(np.mean(np.abs(test_y.values - fc_rf.values)))))   # mean absolute error (MAE), $ millions
