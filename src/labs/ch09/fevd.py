#| **Same VAR(4), baseline ordering.**
from statsmodels.tsa.api import VAR           # vector autoregression model
q = lambda i: fred(i, to="quarter")           # helper: FRED series as quarterly averages
# inflation (annualized %), unemployment, funds rate as columns; keep quarters where all three exist
y = pd.concat({"infl": 400 * np.log(q("CPIAUCSL")).diff(), "unemp": q("UNRATE"), "ffr": q("FEDFUNDS")}, axis=1).dropna()
y = y["1960-01-01":"2000-12-31"]              # Stock–Watson sample, 1960Q1 to 2000Q4
y.index.freq = "QS"                           # quarterly data (quarter-start dates)
m = VAR(y).fit(4)                             # VAR(4); column order = Cholesky ordering

#| **Forecast error variance decomposition.** `m.fevd(20).decomp` has shape (variable, horizon, shock). Rows for unemployment at horizons 1, 4, 8, 12 and 20 match R's `fevd()`.
fe = m.fevd(20).decomp                        # 3-D array: [variable, horizon, shock]
# unemployment (variable 1, counting from 0), horizons 1-20
u = pd.DataFrame(fe[1], columns=y.columns, index=range(1, 21))
print(u.loc[[1, 4, 8, 12, 20]].round(3))      # .loc picks rows by label: selected horizons

#| **Stacked shares by horizon.**
viz_custom("ch09-fevd", h=list(range(1, 21)), response="Unemployment",   # stacked shares chart, one band per shock
           shares={"Inflation": u["infl"].tolist(), "Unemployment": u["unemp"].tolist(), "Fed funds": u["ffr"].tolist()},
           title="Five years out, inflation shocks explain half of unemployment's forecast errors",
           subtitle="Share of the h-quarter-ahead forecast error variance of unemployment, by shock")

#| **All three variables at 20 quarters**, in percent.
# horizon 20 is index 19 (Python counts from 0); rows = forecast variable, columns = shock
tab = pd.DataFrame(100 * fe[:, 19, :], columns=["Inflation shock", "Unemployment shock", "Fed funds shock"])
tab.insert(0, "Forecast", ["Inflation", "Unemployment", "Fed funds"])   # add a label column at the front
viz_table(tab, digits=1, title="Percent of 20-quarter-ahead forecast error variance, by shock")
