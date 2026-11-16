from sklearn.ensemble import RandomForestRegressor
from sklearn.inspection import permutation_importance
retail = fred("RSXFSN", start=2010)           # monthly retail sales, $ millions, not seasonally adjusted
g = 100 * np.log(retail).diff()               # monthly growth, % (the target)
# target, lags 1, 2 and 12 (.shift(k) moves values down k rows), calendar month 1-12
d = pd.DataFrame({"g": g, "g1": g.shift(1), "g2": g.shift(2), "g12": g.shift(12), "month": g.index.month})
train = d[:"2022-12"].dropna()                # training rows: through Dec 2022
test = d["2023-01":]                          # test rows: 2023 onward

# Permutation importance on the test months, as a % increase in test MSE
# (scikit-learn has no out-of-bag version, so we shuffle each feature in the test rows instead)
def imp_pct(rf, cols):
    mse = np.mean((test["g"] - rf.predict(test[cols])) ** 2)   # test MSE before shuffling
    pi = permutation_importance(rf, test[cols], test["g"], scoring="neg_mean_squared_error", n_repeats=10, random_state=1)
    return pd.Series(100 * pi.importances_mean / mse, index=cols).round()
def mae(rf, cols):                            # test MAE, pp of monthly growth
    return round(float(np.mean(np.abs(test["g"] - rf.predict(test[cols])))), 2)
def forest(cols):                             # same settings and seed every time
    return RandomForestRegressor(n_estimators=300, max_features=2, min_samples_split=5, random_state=1).fit(train[cols], train["g"])

# The manager's chart: all four features
full_cols = ["g1", "g2", "g12", "month"]
rf_full = forest(full_cols)

# 1. Drop the calendar month: keep the two recent lags and the seasonal lag
small_cols = ["g1", "g2", "______"]       # blank: the column with last year's growth in the same month
rf_small = forest(small_cols)

# 2. Importance in the smaller forest, then compare both models side by side
imp_full = imp_pct(rf_full, full_cols)        # % increase in test MSE, full model
imp_small = imp_pct(______, small_cols)       # blank: the forest without month
print(imp_full.to_dict()); print(imp_small.to_dict())
print({"full": mae(rf_full, full_cols), "without_month": mae(rf_small, small_cols)})   # did accuracy really suffer?
