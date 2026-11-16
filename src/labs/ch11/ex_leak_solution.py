from sklearn.ensemble import RandomForestRegressor
retail = fred("RSXFSN", start=2010)           # monthly retail sales, $ millions, not seasonally adjusted
g = 100 * np.log(retail).diff()               # monthly growth, % (the target)

# Your colleague's rolling mean: .rolling(3).mean() averages months t-2, t-1 AND t (this month!)
roll3_colleague = g.rolling(3).mean()

d = pd.DataFrame({"g": g, "g1": g.shift(1), "g2": g.shift(2),   # target and two lags (.shift(k) moves values down k rows)
                  "roll3_leaky": roll3_colleague})              # the colleague's feature

# 1. FIX: shift the colleague's mean down one row, so the window is t-3, t-2, t-1 (all known before month t)
d["roll3"] = roll3_colleague.shift(1)

train = d[:"2022-12"].dropna()                # training rows: through Dec 2022, no missing values
test = d["2023-01":]                          # test rows: 2023 onward

# Same forest settings and seed for both, so only the rolling feature differs
leaky_cols, honest_cols = ["g1", "g2", "roll3_leaky"], ["g1", "g2", "roll3"]
rf_leaky = RandomForestRegressor(n_estimators=300, max_features=2, min_samples_split=5, random_state=1).fit(train[leaky_cols], train["g"])
rf_honest = RandomForestRegressor(n_estimators=300, max_features=2, min_samples_split=5, random_state=1).fit(train[honest_cols], train["g"])

# 2. Test MAE in percentage points of monthly growth: actual growth minus the forecast
def mae(model, cols):
    return float(np.mean(np.abs(test["g"] - model.predict(test[cols]))))
mae_leaky = mae(rf_leaky, leaky_cols)         # looks great, but uses this month's value
mae_honest = mae(rf_honest, honest_cols)      # what you could really achieve
print({"leaky": round(mae_leaky, 2), "honest": round(mae_honest, 2)})
