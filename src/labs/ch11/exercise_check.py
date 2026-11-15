_d = d.copy(); _d["gap1"] = (100 * np.log(permits / starts)).shift(1)
_tr, _te = _d[:"2022-12"].dropna(), _d["2023-01":]
_cols = ["g1", "g2", "g12", "gap1"]
_m = RandomForestRegressor(n_estimators=300, max_features=2, min_samples_split=5, random_state=1).fit(_tr[_cols], _tr["g"])
_truth = float(np.mean(np.abs(_te["level"] - _te["prev"] * np.exp(_m.predict(_te[_cols]) / 100))))
_ok = "mae_plus" in dir() and "mae_base" in dir() and abs(mae_plus - _truth) < 1e-6 and "gap1" in plus_cols
check_that(_ok,
    f"With the permits gap, the forest's one-month-ahead MAE drops from {mae_base:.1f} to {_truth:.1f} thousand units (annual rate). Permits come before starts, so a big pile of permits relative to starts signals starts to come. Now try the growth of permits instead, (100 * np.log(permits).diff()).shift(1): the size of the pipeline matters more than its last wiggle.",
    "Check both blanks: the first is the permits series (the numerator of the gap), the second adds the column name 'gap1' to the feature list. Don't change the seed or the settings.")
