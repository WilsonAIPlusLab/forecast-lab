# Hidden check (not shown to students): refits the forest without month and compares importances.
_m = forest(["g1", "g2", "g12"]); _imp = imp_pct(_m, ["g1", "g2", "g12"])
_ok = "imp_small" in dir() and sorted(imp_small.index) == ["g1", "g12", "g2"] and float(imp_small["g12"]) == float(_imp["g12"])
check_that(_ok,
    f"Right. Without month, the seasonal lag's importance jumps from {imp_full['g12']:.0f}% to {_imp['g12']:.0f}%, while the test MAE rises only a little ({mae(rf_full, full_cols):.2f} vs {mae(_m, ['g1', 'g2', 'g12']):.2f} points). Month and g12 carry the same seasonal information, so with both in the model each one can stand in for the other and the credit is split. Importance tells you how much this fitted model leans on a feature, not how much the feature matters in the world. Drop both, and the MAE nearly doubles (about 3.55).",
    "Not yet. Blank 1 is the seasonal lag's column name, 'g12' (keep the quotes). Blank 2 is the smaller forest you just fitted, rf_small.")
