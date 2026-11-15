#| **Build three quarterly series.** `fred(..., to="quarter")` averages the monthly data within each quarter. Inflation is the annualized quarterly change in the CPI (SA). Unemployment (SA) and the funds rate are in percent.
from statsmodels.tsa.api import VAR           # vector autoregression model
# helper (a lambda is a one-line function): FRED series as quarterly averages
q = lambda i: fred(i, to="quarter")
infl = 400 * np.log(q("CPIAUCSL")).diff()     # CPI inflation, % at an annual rate (log change x 4 quarters x 100)
# put the three series side by side as columns; dropna() keeps quarters where all three exist
y = pd.concat({"infl": infl, "unemp": q("UNRATE"), "ffr": q("FEDFUNDS")}, axis=1).dropna()
y = y["1960-01-01":"2000-12-31"]              # Stock–Watson sample: 1960Q1 to 2000Q4 (slice rows by date)
y.index.freq = "QS"                           # tell statsmodels the data are quarterly (quarter-start dates)
print(y.shape)                                # (quarters, variables)

#| **Look before you model.** One panel per series, with recessions shaded.
# **{...} passes a label with a space ("Fed funds") as a keyword argument
viz_ts(Inflation=y["infl"], Unemployment=y["unemp"], **{"Fed funds": y["ffr"]},
       facet=True, recessions=True, ylab="% (inflation annualized)",   # facet = separate panels
       title="The Volcker spike: rates, inflation and jobs move together")

#| **How many lags?** `select_order(8)` is the statsmodels version of `VARselect()`. Same answer: 3 by every criterion. We use 4, as Stock and Watson did.
model = VAR(y)                                # set up the VAR (not fitted yet)
# best lag (1 to 8) by each criterion
print({k: int(v) for k, v in model.select_order(8).selected_orders.items()})

#| **Fit the VAR(4)** and print the first coefficients of the unemployment equation. They match R's `coef(m)$unemp` (statsmodels lists the constant first).
m = model.fit(4)                              # VAR(4): 4 lags (one year of quarters) plus a constant
print(m.params["unemp"].head(7).round(3))     # first 7 coefficients of the unemployment equation

#| **Stability and residual correlation.** statsmodels reports the inverse roots of the characteristic polynomial; the largest moduli match R's `roots()` (0.948). Then the residual correlation matrix.
print(np.sort(np.abs(1 / m.roots))[::-1][:3].round(3))   # three largest moduli of 1/root; all below 1 means stable
print(m.resid.corr().round(2))                # how correlated the three equations' surprises are
