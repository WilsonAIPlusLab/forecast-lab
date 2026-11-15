from statsmodels.tsa.api import VAR    # vector autoregression model
q = lambda i: fred(i, to="quarter")    # helper: FRED series as quarterly averages
# term spread (10-year minus 3-month, points) and unemployment (%); common quarters only
z = pd.concat({"spread": q("GS10") - q("TB3MS"), "unemp": q("UNRATE")}, axis=1).dropna()
z = z["1960-01-01":"2000-12-31"]       # 1960Q1 to 2000Q4
z.index.freq = "QS"                    # quarterly data (quarter-start dates)

# 1. Let BIC choose the lag length (statsmodels calls it "bic")
# blank: the key for BIC in the selected_orders dictionary
p = int(VAR(z).select_order(8).selected_orders["______"])

# 2. Fit a two-variable VAR with that many lags
m = VAR(z).fit(p)

# 3. Does the spread Granger-cause unemployment? Store the p-value.
# blank: the column name of the causing variable (the second argument)
pval = m.test_causality("unemp", "______", kind="f").pvalue
print(p, pval)                         # small p-value = its past helps predict unemployment
