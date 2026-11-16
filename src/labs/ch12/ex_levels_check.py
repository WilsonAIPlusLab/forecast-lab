# Hidden check (not shown to students): refits the levels model and confirms both blanks.
_m = xgb.train({"eta": 0.1, "max_depth": 2, "tree_method": "exact", "nthread": 1},
               xgb.DMatrix(tr[lev], label=tr["sales"] / 1000), num_boost_round=143)
_p = _m.predict(xgb.DMatrix(te[lev])); _cap = tr["sales"].max() / 1000
_ok_fit = "pred_lev" in dir() and len(pred_lev) == len(te) and float(np.max(np.abs(np.asarray(pred_lev) - _p))) < 1e-3
check_that(_ok_fit and "ceiling_bn" in dir() and abs(float(ceiling_bn) - _cap) < 1e-6,
    f"No forecast tops ${_cap:.1f}bn: the highest is ${_p.max():.1f}bn, below the training record of ${_cap:.1f}bn, while actual sales reached "
    f"${te['sales'].max() / 1000:.1f}bn. Trees answer with values built from months they have seen, so a levels model hits a ceiling near its training record, "
    f"and its MAE (${np.mean(np.abs(te['sales'] / 1000 - _p)):.1f}bn) is more than double the growth model's ($10.35bn). "
    "Predict growth, then convert back: last month x (1 + growth/100).",
    "The model is right. For the ceiling, take the largest value of tr['sales'] and convert $ millions to $ billions (divide by 1,000)." if _ok_fit else
    "The label must be the training sales in $ billions: tr['sales'] divided by 1,000. (Use tr, the training rows, not te.)")
