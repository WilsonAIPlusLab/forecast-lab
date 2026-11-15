#| **Start from a series.** Retail sales (RSXFSN, $ millions, **not** seasonally adjusted) from 2010. The target is monthly growth in percent: `100 * diff(log(sales))`.
retail = fred("RSXFSN", start=2010)
g = (100 * np.log(retail).diff()).dropna()
print(g.tail(13).round(1))

#| **A lag in one line.** In pandas, `.shift(k)` slides a column down `k` rows, so row *t* holds the value from *t − k*. `.shift(1).rolling(3).mean()` is a rolling mean whose window **ends at t − 1**.
print(pd.Series([1, 2, 3, 4, 5, 6]).shift(2).tolist())

#| **Build the supervised-learning table.** One row per month: the target `g` and features you would know *before* the month starts (lags, the seasonal lag `g12`, a past-only rolling mean, the calendar month and a trend counter).
def make_features(g):
    return pd.DataFrame({
        "g": g, "g1": g.shift(1), "g2": g.shift(2), "g12": g.shift(12),
        "roll3": g.shift(1).rolling(3).mean(),
        "month": g.index.month, "trend": np.arange(1, len(g) + 1)}, index=g.index)

feats = make_features(g)
print(feats.tail(4).round(2))

#| **A leakage test.** A rolling mean whose window *includes* this month, `g.rolling(3).mean()`, contains the answer: with the two lags it reproduces the target exactly (R² = 1), because `g = 3 × leaky_roll3 − g1 − g2`. That skill vanishes the day you forecast for real.
import statsmodels.api as sm
leaky = g.rolling(3).mean()
def r2(X):
    ok = X.notna().all(axis=1)
    return sm.OLS(feats.loc[ok, "g"], sm.add_constant(X[ok])).fit().rsquared
print({"honest": round(float(r2(feats[["g1", "g2", "roll3"]])), 3),
       "leaky": round(float(r2(feats[["g1", "g2"]].assign(leaky_roll3=leaky))), 3)})

#| **Split by time, then drop incomplete rows.** Training ends in December 2022; the test set is 2023 onward, the same split as the Chapter 3 scorecard.
train = feats[:"2022-12"].dropna()
test = feats["2023-01":]
print({"train_rows": len(train), "test_rows": len(test)})

#| **The finished table**: rows of features and a target, ready for any machine-learning model.
tab = train[["month", "g12", "g2", "g1", "roll3", "g"]].tail(8).copy()
tab.insert(0, "date", tab.index.strftime("%Y-%m"))
viz_table(tab.reset_index(drop=True), digits=1, title="A time series, rebuilt as a supervised-learning table")
