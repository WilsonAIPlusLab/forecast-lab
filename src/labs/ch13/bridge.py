#| **Weekly claims with their real week-ending dates.** `fred("ICSA")` keeps the Saturday dates in the index, so we can tell which weeks belong to which month. The last rows are the **ragged edge**: the newest data that exist today.
import statsmodels.formula.api as smf              # R-style formulas: smf.ols("y ~ x", data)
claims = fred("ICSA") / 1000                       # thousands, SA
print(claims.tail(4))                              # last 4 weeks, indexed by week-ending date

#| **Aggregate weekly to monthly.** Average the weeks whose week-ending date falls in each month, and count them. The latest month has only one week so far: a *partial* aggregate that will change as more Thursdays arrive.
# group weeks by calendar month (to_period("M")), then take the mean and the count of weeks
cl = claims.groupby(claims.index.to_period("M")).agg(["mean", "size"])
cl.columns = ["k", "weeks"]                        # k = average weekly claims, weeks = how many so far
print(cl.tail(3))                                  # newest month is a partial average

#| **Line up the monthly target**: the change in nonfarm payrolls (thousands of jobs, SA), last month's change, and the change in average claims.
pay = fred("PAYEMS", start=1989)                   # nonfarm payrolls, thousands of jobs
d = pd.DataFrame({"dp": pay.diff()})               # dp = monthly change (NaN for the first month)
d.index = d.index.to_period("M")                   # monthly periods, so it lines up with cl
d["dp_lag"] = d["dp"].shift(1)                     # .shift(1) moves values down a row: last month's change
d["cl"] = cl["k"].reindex(d.index)                 # attach monthly claims by matching months
d["dcl"] = d["cl"].diff()                          # change in average claims vs last month
d["yr"] = d.index.year                             # calendar year, used to filter the sample
print(d.tail(3))                                   # newest month has claims but no payroll yet

#| **Fit the bridge equation**, skipping 2020–2021 so COVID's multi-million swings don't swamp least squares. Compare the residual standard errors: claims help, but only a little.
def sample(df):
    # estimation sample: 1990 on, no COVID years (~ means "not"), no missing values
    return df[(df.yr >= 1990) & ~df.yr.isin([2020, 2021])].dropna(subset=["dp", "dp_lag", "dcl"])
est = sample(d)
bridge = smf.ols("dp ~ dp_lag + dcl", est).fit()   # bridge: last month's jobs + claims change
ar = smf.ols("dp ~ dp_lag", est).fit()             # benchmark: last month's jobs only (AR(1))
print(bridge.params.round(2))                      # intercept and slopes
# residual standard errors (typical miss); .scale is the residual variance, so take its square root
print({"bridge_sigma": round(float(np.sqrt(bridge.scale)), 2), "ar_sigma": round(float(np.sqrt(ar.scale)), 2)})

#| **Nowcast November 2026 from one week of claims**, with a 90% prediction interval (statsmodels calls its bounds `obs_ci_lower`/`obs_ci_upper`).
# inputs for November: October's payroll change, and newest claims average minus the previous month's
now = pd.DataFrame({"dp_lag": [d["dp"].iloc[-1]], "dcl": [cl["k"].iloc[-1] - cl["k"].iloc[-2]]})
pr = bridge.get_prediction(now).summary_frame(alpha=0.10)   # alpha = 0.10 -> 90% interval
print(pr[["mean", "obs_ci_lower", "obs_ci_upper"]].round(0))   # thousands of jobs

#| **Honest test**: re-fit on earlier data only, nowcast each month, and compare a calm period with a recession. Inside the loop we use plain `np.linalg.lstsq` (the same least squares, much faster than re-parsing a formula 72 times).
# helper: fit OLS of dp on the given columns using tr, then predict for one row
def fit_predict(tr, row, cols):
    X = np.column_stack([np.ones(len(tr))] + [tr[c] for c in cols])   # design matrix: intercept + predictors
    b = np.linalg.lstsq(X, tr["dp"], rcond=None)[0]                    # least-squares coefficients
    return b[0] + sum(b[j + 1] * row[c] for j, c in enumerate(cols))   # intercept + slope x value
# helper: out-of-sample nowcasts for every month from start to end
def oos(start, end):
    out = []
    for p in d.loc[start:end].index:                   # .loc[start:end] selects the test months by label
        tr, row = sample(d.loc[:p - 1]), d.loc[p]      # train on months before p only; row = month p
        out.append({"actual": row.dp, "AR": fit_predict(tr, row, ["dp_lag"]),
                    "Bridge": fit_predict(tr, row, ["dp_lag", "dcl"])})
    return pd.DataFrame(out)                           # one row per month: truth, AR, bridge
mae = lambda r: (r[["AR", "Bridge"]].sub(r.actual, axis=0)).abs().mean()   # mean absolute error per model
score = pd.DataFrame({"2023-2026 (calm)": mae(oos("2023-01", "2026-10")),        # calm period
                      "2008-2009 (recession)": mae(oos("2008-01", "2009-12"))})  # Great Recession
print(score.round(1))                                  # thousands of jobs; lower is better
viz_table(score, highlight=list(score.columns), digits=0,   # green = lower MAE in each period
          title="Claims help most in a downturn: nowcast MAE, thousands of jobs")
