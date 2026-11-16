# Hidden check (not shown to students): rebuilds the honest feature and compares the test MAE.
_d = d.copy(); _d["roll3"] = g.rolling(3).mean().shift(1)
_tr, _te = _d[:"2022-12"].dropna(), _d["2023-01":]
_m = RandomForestRegressor(n_estimators=300, max_features=2, min_samples_split=5, random_state=1).fit(_tr[["g1", "g2", "roll3"]], _tr["g"])
_truth = float(np.mean(np.abs(_te["g"] - _m.predict(_te[["g1", "g2", "roll3"]]))))
_ok = "mae_honest" in dir() and "mae_leaky" in dir() and d["roll3"].equals(_d["roll3"]) and abs(mae_honest - _truth) < 1e-6
check_that(_ok,
    f"Fixed. The leaky forest 'misses' by only {mae_leaky:.2f} points on the 2023+ test months; the honest one by {_truth:.2f}. The leak flattered the test score too, because the test rows were built with the same leaky formula. A held-out test set cannot catch a leak in the features: only checking every window can. Rule of thumb: in a forecasting table, every rolling statistic gets a lag of at least 1.",
    "Not yet. Blank 1 is how many rows to shift the colleague's mean so its window ends last month (a small whole number). Blank 2 is the actual growth on the test rows: the column test['g']. Don't change the seed or the settings.")
