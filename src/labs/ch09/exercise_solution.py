from statsmodels.tsa.api import VAR    # vector autoregression model
q = lambda i: fred(i, to="quarter")    # helper: FRED series as quarterly averages
# term spread (10-year minus 3-month, points) and unemployment (%); common quarters only
z = pd.concat({"spread": q("GS10") - q("TB3MS"), "unemp": q("UNRATE")}, axis=1).dropna()
z = z["1960-01-01":"2000-12-31"]       # 1960Q1 to 2000Q4
z.index.freq = "QS"                    # quarterly data (quarter-start dates)

# 1. Let BIC choose the lag length (statsmodels calls it "bic")
p = int(VAR(z).select_order(8).selected_orders["bic"])   # lag count BIC prefers, from 1 to 8

# 2. Fit a two-variable VAR with that many lags
m = VAR(z).fit(p)

# 3. Does the spread Granger-cause unemployment? Store the p-value.
pval = m.test_causality("unemp", "spread", kind="f").pvalue   # F-test: do past spreads help predict unemployment?
print(p, pval)                         # small p-value = the spread carries information
