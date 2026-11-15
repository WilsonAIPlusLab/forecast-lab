#| **Same data, same VAR(4).**
from statsmodels.tsa.api import VAR           # vector autoregression model
q = lambda i: fred(i, to="quarter")           # helper: FRED series as quarterly averages
# inflation (annualized %), unemployment, funds rate as columns; keep quarters where all three exist
y = pd.concat({"infl": 400 * np.log(q("CPIAUCSL")).diff(), "unemp": q("UNRATE"), "ffr": q("FEDFUNDS")}, axis=1).dropna()
y = y["1960-01-01":"2000-12-31"]              # Stock–Watson sample, 1960Q1 to 2000Q4
y.index.freq = "QS"                           # quarterly data (quarter-start dates)
m = VAR(y).fit(4)                             # VAR(4) with a constant

#| **Does the funds rate help predict the other two?** `test_causality(caused, causing, kind="f")` is the same F-test as R's `causality()`: F = 2.53 on (8, 441) degrees of freedom, p = 0.011.
t = m.test_causality(["infl", "unemp"], "ffr", kind="f")   # does ffr's past help predict infl and unemp?
print(t.summary())                            # F statistic, degrees of freedom, p-value

#| **Every variable in turn.**
rows = {}                                     # results, one entry per causing variable
for v in y.columns:
    others = [c for c in y.columns if c != v] # list comprehension: every column except v
    r = m.test_causality(others, v, kind="f") # does the past of v help predict the other two?
    rows[v] = {"F": r.test_statistic, "df1": r.df[0], "p.value": r.pvalue}
# .T = one row per variable
viz_table(pd.DataFrame(rows).T, digits=7, title="Every variable Granger-causes the others in 1960–2000")

#| **Same question, different decades:** does the term spread help predict unemployment?
# two-variable system: term spread (10-year minus 3-month, points) and unemployment
z = pd.concat({"spread": q("GS10") - q("TB3MS"), "unemp": q("UNRATE")}, axis=1).dropna()
def p_spread(a, b):                           # p-value of "spread Granger-causes unemp" for dates a to b
    w = z[a:b].copy(); w.index.freq = "QS"    # sub-sample, marked as quarterly
    return VAR(w).fit(4).test_causality("unemp", "spread", kind="f").pvalue   # VAR(4) on the sub-sample
print({"1960-2000": round(float(p_spread("1960-01-01", "2000-12-31")), 4), "1985-2019": round(float(p_spread("1985-01-01", "2019-12-31")), 4)})
