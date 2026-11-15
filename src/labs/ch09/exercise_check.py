_z = pd.concat({"spread": q("GS10") - q("TB3MS"), "unemp": q("UNRATE")}, axis=1).dropna()
def _p(a, b):
    w = _z[a:b].copy(); w.index.freq = "QS"
    k = int(VAR(w).select_order(8).selected_orders["bic"])
    return k, float(VAR(w).fit(k).test_causality("unemp", "spread", kind="f").pvalue)
_k, _truth = _p("1960-01-01", "2000-12-31")
_, _late = _p("1985-01-01", "2019-12-31")
check_that("pval" in globals() and "p" in globals() and p == _k and abs(float(pval) - _truth) < 1e-8,
    f"BIC picks {_k} lags and the p-value is {_truth:.2g}: in 1960–2000 the slope of the yield curve really did carry information about future unemployment. "
    f"Now change the window to 1985–2019: the p-value becomes {_late:.2f}. In the recent sample the signal all but disappears in this simple test, "
    "so a good forecaster re-tests old relationships instead of trusting them forever.",
    'Check the two blanks. The BIC key of selected_orders is "bic", and the causing variable must be the spread column, "spread".')
