#| **Weekly claims with their real week-ending dates.** `fred("ICSA")` keeps the Saturday dates in the index, so we can tell which weeks belong to which month. The last rows are the **ragged edge**: the newest data that exist today.
import statsmodels.formula.api as smf
claims = fred("ICSA") / 1000                       # thousands, SA
print(claims.tail(4))

#| **Aggregate weekly to monthly.** Average the weeks whose week-ending date falls in each month, and count them. The latest month has only one week so far: a *partial* aggregate that will change as more Thursdays arrive.
cl = claims.groupby(claims.index.to_period("M")).agg(["mean", "size"])
cl.columns = ["k", "weeks"]
print(cl.tail(3))

#| **Line up the monthly target**: the change in nonfarm payrolls (thousands of jobs, SA), last month's change, and the change in average claims.
pay = fred("PAYEMS", start=1989)
d = pd.DataFrame({"dp": pay.diff()})
d.index = d.index.to_period("M")
d["dp_lag"] = d["dp"].shift(1)
d["cl"] = cl["k"].reindex(d.index)
d["dcl"] = d["cl"].diff()
d["yr"] = d.index.year
print(d.tail(3))

#| **Fit the bridge equation**, skipping 2020–2021 so COVID's multi-million swings don't swamp least squares. Compare the residual standard errors: claims help, but only a little.
def sample(df):
    return df[(df.yr >= 1990) & ~df.yr.isin([2020, 2021])].dropna(subset=["dp", "dp_lag", "dcl"])
est = sample(d)
bridge = smf.ols("dp ~ dp_lag + dcl", est).fit()
ar = smf.ols("dp ~ dp_lag", est).fit()
print(bridge.params.round(2))
print({"bridge_sigma": round(float(np.sqrt(bridge.scale)), 2), "ar_sigma": round(float(np.sqrt(ar.scale)), 2)})

#| **Nowcast November 2026 from one week of claims**, with a 90% prediction interval (statsmodels calls its bounds `obs_ci_lower`/`obs_ci_upper`).
now = pd.DataFrame({"dp_lag": [d["dp"].iloc[-1]], "dcl": [cl["k"].iloc[-1] - cl["k"].iloc[-2]]})
pr = bridge.get_prediction(now).summary_frame(alpha=0.10)
print(pr[["mean", "obs_ci_lower", "obs_ci_upper"]].round(0))

#| **Honest test**: re-fit on earlier data only, nowcast each month, and compare a calm period with a recession. Inside the loop we use plain `np.linalg.lstsq` (the same least squares, much faster than re-parsing a formula 72 times).
def fit_predict(tr, row, cols):
    X = np.column_stack([np.ones(len(tr))] + [tr[c] for c in cols])
    b = np.linalg.lstsq(X, tr["dp"], rcond=None)[0]
    return b[0] + sum(b[j + 1] * row[c] for j, c in enumerate(cols))
def oos(start, end):
    out = []
    for p in d.loc[start:end].index:
        tr, row = sample(d.loc[:p - 1]), d.loc[p]
        out.append({"actual": row.dp, "AR": fit_predict(tr, row, ["dp_lag"]),
                    "Bridge": fit_predict(tr, row, ["dp_lag", "dcl"])})
    return pd.DataFrame(out)
mae = lambda r: (r[["AR", "Bridge"]].sub(r.actual, axis=0)).abs().mean()
score = pd.DataFrame({"2023-2026 (calm)": mae(oos("2023-01", "2026-10")),
                      "2008-2009 (recession)": mae(oos("2008-01", "2009-12"))})
print(score.round(1))
viz_table(score, highlight=list(score.columns), digits=0,
          title="Claims help most in a downturn: nowcast MAE, thousands of jobs")
