#| **Build three quarterly series.** `fred(..., to="quarter")` averages the monthly data within each quarter. Inflation is the annualized quarterly change in the CPI (SA). Unemployment (SA) and the funds rate are in percent.
from statsmodels.tsa.api import VAR
q = lambda i: fred(i, to="quarter")
infl = 400 * np.log(q("CPIAUCSL")).diff()
y = pd.concat({"infl": infl, "unemp": q("UNRATE"), "ffr": q("FEDFUNDS")}, axis=1).dropna()
y = y["1960-01-01":"2000-12-31"]
y.index.freq = "QS"
print(y.shape)

#| **Look before you model.** One panel per series, with recessions shaded.
viz_ts(Inflation=y["infl"], Unemployment=y["unemp"], **{"Fed funds": y["ffr"]},
       facet=True, recessions=True, ylab="% (inflation annualized)",
       title="The Volcker spike: rates, inflation and jobs move together")

#| **How many lags?** `select_order(8)` is the statsmodels version of `VARselect()`. Same answer: 3 by every criterion. We use 4, as Stock and Watson did.
model = VAR(y)
print({k: int(v) for k, v in model.select_order(8).selected_orders.items()})

#| **Fit the VAR(4)** and print the first coefficients of the unemployment equation. They match R's `coef(m)$unemp` (statsmodels lists the constant first).
m = model.fit(4)
print(m.params["unemp"].head(7).round(3))

#| **Stability and residual correlation.** statsmodels reports the inverse roots of the characteristic polynomial; the largest moduli match R's `roots()` (0.948). Then the residual correlation matrix.
print(np.sort(np.abs(1 / m.roots))[::-1][:3].round(3))
print(m.resid.corr().round(2))
