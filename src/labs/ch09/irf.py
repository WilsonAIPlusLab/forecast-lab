#| **Rebuild the VAR(4)**, columns ordered inflation, unemployment, funds rate.
from statsmodels.tsa.api import VAR           # vector autoregression model
q = lambda i: fred(i, to="quarter")           # helper: FRED series as quarterly averages
# inflation (annualized %), unemployment, funds rate as columns; keep quarters where all three exist
y = pd.concat({"infl": 400 * np.log(q("CPIAUCSL")).diff(), "unemp": q("UNRATE"), "ffr": q("FEDFUNDS")}, axis=1).dropna()
y = y["1960-01-01":"2000-12-31"]              # Stock–Watson sample, 1960Q1 to 2000Q4
y.index.freq = "QS"                           # quarterly data (quarter-start dates)
m = VAR(y).fit(4)                             # VAR(4); column order = Cholesky ordering

#| **Orthogonalized impulse responses.** `m.irf(20).orth_irfs` has shape (horizon, response, impulse) and uses the Cholesky ordering of the columns. The numbers match R's `irf()` exactly. For bands, statsmodels offers `errband_mc()`, a Monte Carlo method that simulates from the estimated VAR; R's `vars` resamples residuals (bootstrap). The two bands are similar but not identical, and both wiggle a little from run to run.
ir = m.irf(20)                                # impulse responses for horizons 0 to 20 quarters
k = list(y.columns).index("ffr")              # position of the funds rate (the shock variable)
resp = pd.DataFrame(ir.orth_irfs[:, :, k], columns=y.columns)   # every variable's response to a funds-rate shock
print(resp.head(9).round(3))                  # first 9 quarters (row 0 is the shock quarter)
np.random.seed(2001)   # errband_mc draws from NumPy's global random generator
lo, hi = ir.errband_mc(orth=True, repl=100, signif=0.10)   # 90% Monte Carlo bands from 100 simulations

#| **Draw it** with the chapter's impulse-response chart: one panel per response, band shaded.
# helper: one chart panel for response `res`; each run is a tuple (irfs, lower, upper, shock index)
def panel(res, label, **runs):
    j = list(y.columns).index(res)            # position of the response variable
    # list comprehension: one series per named run; r[0..3] = irfs, lower, upper, shock index
    return dict(name=label, series=[dict(name=n, pt=r[0][:, j, r[3]].tolist(),
                lo=None if r[1] is None else r[1][:, j, r[3]].tolist(),   # lower band, if any
                # upper band, if any
                hi=None if r[2] is None else r[2][:, j, r[3]].tolist()) for n, r in runs.items()])
base = (ir.orth_irfs, lo, hi, k)              # baseline ordering ("Fed last"), with bands
viz_custom("ch09-irf", h=list(range(21)), xlab="quarters after the shock", unit="pp",   # pp = percentage points
           panels=[panel("infl", "Inflation", **{"Fed last": base}), panel("unemp", "Unemployment", **{"Fed last": base}),
                   panel("ffr", "Fed funds rate", **{"Fed last": base})],
           title="A surprise hike: unemployment rises slowly; inflation first rises (the price puzzle)",
           subtitle="Response to a 0.76 pp funds-rate shock, VAR(4) 1960–2000, 90% Monte Carlo bands")

#| **Put the Fed first** and compare. Only the column order changes.
y2 = y[["ffr", "infl", "unemp"]]              # same data, funds rate ordered first
ir2 = VAR(y2).fit(4).irf(20)                  # method chaining: fit the VAR(4), then compute IRFs
alt = ir2.orth_irfs[:, :, 0][:, [1, 2, 0]]           # reorder responses to infl, unemp, ffr
alt3 = np.zeros_like(ir.orth_irfs); alt3[:, :, k] = alt   # same 3-D shape as the baseline, so panel() can read it
# unemployment, both orderings
print(pd.DataFrame({"Fed last": resp["unemp"], "Fed first": alt[:, 1]}).head(9).round(3))
# both orderings in each panel
viz_custom("ch09-irf", h=list(range(21)), xlab="quarters after the shock", unit="pp",
           panels=[panel("infl", "Inflation", **{"Fed last": base, "Fed first": (alt3, None, None, k)}),
                   panel("unemp", "Unemployment", **{"Fed last": base, "Fed first": (alt3, None, None, k)})],
           title="Same data, two orderings, opposite short-run stories",
           subtitle="Response to a one-s.d. funds-rate shock; band shown for the baseline ordering only")
