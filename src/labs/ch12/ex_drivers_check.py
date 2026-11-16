# Hidden check (not shown to students): recomputes the dollar SHAP values and the top three drivers.
_S = pd.Series(fit.predict(xgb.DMatrix(mar[features]), pred_contribs=True)[0], index=features + ["base"])
_u = _S[features] * mar["lag1"].iloc[0] / 100 / 1000
_t = list(_u.abs().sort_values(ascending=False).index[:3])
_ok_usd = "usd" in dir() and len(usd) == len(features) and np.allclose(np.asarray(usd, dtype=float), _u.values, rtol=1e-6)
check_that(_ok_usd and "top3" in dir() and list(top3.index) == _t,
    "Three reasons, in dollars: " + ", ".join(f"{k} {_u[k]:+.1f}bn" for k in _t) + ". Notice how the first sentence leads with the number, "
    "the second gives the reasons, and the third says how far to trust them. That is the whole manager briefing. "
    f"Units check: 1 point of growth on February's ${mar['lag1'].iloc[0] / 1000:.1f}bn is worth ${mar['lag1'].iloc[0] / 100 / 1000:.1f}bn.",
    "The dollars are right, but the top three are not. Sort by the size of each push, ignoring its sign: usd.abs()." if _ok_usd else
    "Check the multiplier: points of growth x last month's sales (lag1, in $ millions) / 100 gives $ millions; divide by 1,000 more for $ billions.")
