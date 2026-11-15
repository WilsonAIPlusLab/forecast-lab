from sklearn.ensemble import RandomForestRegressor
starts = fred("HOUST", start=2010)     # housing starts, thousands of units (SAAR)
permits = fred("PERMIT", start=2010)   # building permits, thousands of units (SAAR)
permits = permits[:starts.index[-1]]   # trim permits so both series end in the same month

# The table: target g = growth of starts (%), with lags, as in the chapter
g = 100 * np.log(starts).diff()        # monthly growth of starts, %
# level = this month's starts, prev = last month's starts, then target g and its lags 1, 2, 12
d = pd.DataFrame({"level": starts, "prev": starts.shift(1), "g": g, "g1": g.shift(1), "g2": g.shift(2), "g12": g.shift(12)})

# 1. NEW FEATURE: last month's permits-to-starts gap, in log % (known before this month's starts are out)
d["gap1"] = (100 * np.log(permits / starts)).shift(1)   # .shift(1): only last month's gap is known

train = d[:"2022-12"].dropna()         # training rows: through Dec 2022, no missing values
test = d["2023-01":]                   # test rows: 2023 onward

# 2. Fit the forest without and with the new feature (same seed, same settings)
base_cols = ["g1", "g2", "g12"]
plus_cols = base_cols + ["gap1"]       # same features plus the new gap
rf_base = RandomForestRegressor(n_estimators=300, max_features=2, min_samples_split=5, random_state=1).fit(train[base_cols], train["g"])
rf_plus = RandomForestRegressor(n_estimators=300, max_features=2, min_samples_split=5, random_state=1).fit(train[plus_cols], train["g"])

# One-step-ahead test MAE, back in thousands of units: last month's level x exp(growth forecast)
def mae(model, cols):
    return float(np.mean(np.abs(test["level"] - test["prev"] * np.exp(model.predict(test[cols]) / 100))))
mae_base = mae(rf_base, base_cols)     # error without the new feature
mae_plus = mae(rf_plus, plus_cols)     # error with it: lower is better
print({"base": round(mae_base, 1), "with_gap": round(mae_plus, 1)})
