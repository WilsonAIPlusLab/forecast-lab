#| **Same data, same VAR(4).**
from statsmodels.tsa.api import VAR
q = lambda i: fred(i, to="quarter")
y = pd.concat({"infl": 400 * np.log(q("CPIAUCSL")).diff(), "unemp": q("UNRATE"), "ffr": q("FEDFUNDS")}, axis=1).dropna()
y = y["1960-01-01":"2000-12-31"]
y.index.freq = "QS"
m = VAR(y).fit(4)

#| **Does the funds rate help predict the other two?** `test_causality(caused, causing, kind="f")` is the same F-test as R's `causality()`: F = 2.53 on (8, 441) degrees of freedom, p = 0.011.
t = m.test_causality(["infl", "unemp"], "ffr", kind="f")
print(t.summary())

#| **Every variable in turn.**
rows = {}
for v in y.columns:
    others = [c for c in y.columns if c != v]
    r = m.test_causality(others, v, kind="f")
    rows[v] = {"F": r.test_statistic, "df1": r.df[0], "p.value": r.pvalue}
viz_table(pd.DataFrame(rows).T, digits=7, title="Every variable Granger-causes the others in 1960–2000")

#| **Same question, different decades:** does the term spread help predict unemployment?
z = pd.concat({"spread": q("GS10") - q("TB3MS"), "unemp": q("UNRATE")}, axis=1).dropna()
def p_spread(a, b):
    w = z[a:b].copy(); w.index.freq = "QS"
    return VAR(w).fit(4).test_causality("unemp", "spread", kind="f").pvalue
print({"1960-2000": round(float(p_spread("1960-01-01", "2000-12-31")), 4), "1985-2019": round(float(p_spread("1985-01-01", "2019-12-31")), 4)})
