from statsmodels.tsa.api import VAR
q = lambda i: fred(i, to="quarter")
z = pd.concat({"spread": q("GS10") - q("TB3MS"), "unemp": q("UNRATE")}, axis=1).dropna()
z = z["1960-01-01":"2000-12-31"]
z.index.freq = "QS"

# 1. Let BIC choose the lag length (statsmodels calls it "bic")
p = int(VAR(z).select_order(8).selected_orders["bic"])

# 2. Fit a two-variable VAR with that many lags
m = VAR(z).fit(p)

# 3. Does the spread Granger-cause unemployment? Store the p-value.
pval = m.test_causality("unemp", "spread", kind="f").pvalue
print(p, pval)
