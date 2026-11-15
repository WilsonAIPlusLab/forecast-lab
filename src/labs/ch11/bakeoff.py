#| **Same data, same split as the Chapter 3 scorecard**: retail sales (RSXFSN, $ millions, NSA) from 2010, train through 2022, test from January 2023.
from sklearn.ensemble import RandomForestRegressor
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
retail = fred("RSXFSN", start=2010)
train_y, test_y = retail[:"2022-12"], retail["2023-01":]
h = len(test_y)

#| **The statistical contestants.** Seasonal naive, and an ETS(M,A,M) model: the form R's automatic `ets()` picks for this training set.
f_snaive = pd.Series([train_y.iloc[-12 + (i % 12)] for i in range(h)], index=test_y.index)
ets = ETSModel(train_y, error="mul", trend="add", seasonal="mul", seasonal_periods=12).fit(disp=False)
f_ets = pd.Series(np.asarray(ets.forecast(h)), index=test_y.index)

#| **The forest from the previous lab**, rebuilt with the same settings, plus its recursive forecaster.
def make_features(g):
    return pd.DataFrame({"g": g, "g1": g.shift(1), "g2": g.shift(2), "g12": g.shift(12), "month": g.index.month})
def forecast_rf(model, y, h):
    lev = list(y.astype(float)); g = [np.nan] + list(100 * np.diff(np.log(lev))); mon = list(y.index.month)
    for _ in range(h):
        m = mon[-1] % 12 + 1
        g_hat = float(model.predict(pd.DataFrame({"g1": [g[-1]], "g2": [g[-2]], "g12": [g[-12]], "month": [m]}))[0])
        lev.append(lev[-1] * np.exp(g_hat / 100)); g.append(g_hat); mon.append(m)
    return pd.Series(lev[-h:], index=test_y.index[:h])
train = make_features(100 * np.log(train_y).diff()).dropna()
X_cols = ["g1", "g2", "g12", "month"]
grow = lambda seed: RandomForestRegressor(n_estimators=100, max_features=2, min_samples_split=5, random_state=seed).fit(train[X_cols], train["g"])
f_rf = forecast_rf(grow(1), train_y, h)

#| **Score everyone on the same test months** (MASE scaled by the in-sample seasonal naive MAE, as in Chapter 3), including a 50/50 average of ETS and the forest.
scale = (train_y - train_y.shift(12)).abs().mean()
def score(f):
    e = test_y - f
    return {"ME": e.mean(), "MAE": e.abs().mean(), "RMSE": np.sqrt((e ** 2).mean()),
            "MAPE": 100 * (e / test_y).abs().mean(), "MASE": e.abs().mean() / scale}
board = pd.DataFrame({"Seasonal naive": score(f_snaive), "ETS": score(f_ets), "Random forest (growth)": score(f_rf),
                      "ETS + forest average": score((f_ets + f_rf) / 2)}).T
print(board.round(2))

#| **The scorecard.** In Python the forest loses clearly to ETS on this window; see the R tab for a much closer race. Same idea, different implementation, different verdict: one more reason to test every model honestly.
viz_table(board, highlight=["MAE", "RMSE", "MAPE", "MASE"], digits=2, title="ML vs ETS bake-off: retail sales, test period 2023 onward")
viz_compare(history=train_y["2020":], actual=test_y, **{"Seasonal naive": f_snaive, "ETS": f_ets, "Random forest": f_rf},
            title="ETS tracks the test period more closely than the forest")

#| **Is the forest's score luck?** Re-grow it with two more seeds (R's tab tries four).
maes = [board.loc["Random forest (growth)", "MAE"]] + [float(np.mean(np.abs(test_y - forecast_rf(grow(s), train_y, h)))) for s in (2, 3)]
print({f"seed_{s}": round(m) for s, m in zip((1, 2, 3), maes)}, "ETS:", round(board.loc["ETS", "MAE"]))
