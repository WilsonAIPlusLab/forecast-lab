#| **Final GDPNow nowcast per quarter vs real GDP growth as it stands today** (latest vintage, after all revisions). GDPNow was aiming at BEA's *advance* estimate, which is not bundled, so read every number below with that in mind.
# side by side: final GDPNow nowcast and revised real GDP growth, both % annualized
d = pd.concat({"nowcast": fred("GDPNOW"), "actual": fred("A191RL1Q225SBEA")}, axis=1)
d["last_q"] = d["actual"].shift(1)                     # .shift(1) = last quarter's growth (naive forecast)
d = d.dropna()                                         # keep quarters where all three exist
d["error"] = d["actual"] - d["nowcast"]                # error = actual minus nowcast (positive = nowcast too low)
print(d.index[0].date(), d.index[-1].date(), len(d))   # sample span and number of quarters

#| **Nowcast vs outcome**, with the 45° line of perfect nowcasts.
# scatter with a 45-degree line; labels are the quarter dates as text
viz_custom("ch13-scatter45", x=d.nowcast.tolist(), y=d.actual.tolist(), labels=[t.strftime("%Y-%m-%d") for t in d.index],
           xlab="GDPNow final nowcast (% annualized)", ylab="Real GDP growth, latest vintage (%)",
           title="GDPNow tracks the big swings; the everyday misses are a point or two",
           source="FRED, Federal Reserve Bank of St. Louis (GDPNOW, A191RL1Q225SBEA)")

#| **Score it**, with and without the two COVID quarters, against a naive "same as last quarter" benchmark.
# helper: accuracy summary for a set of quarters; Naive MAE uses last quarter's growth as the forecast
def score(z):
    return {"n": len(z), "MAE": z.error.abs().mean(), "RMSE": np.sqrt((z.error ** 2).mean()),
            "Mean error": z.error.mean(), "Naive MAE": (z.actual - z.last_q).abs().mean()}
covid = d.index.isin(pd.to_datetime(["2020-04-01", "2020-07-01"]))   # True for 2020 Q2 and Q3
# ~ means "not"; .T flips the table so each sample is a row
tab = pd.DataFrame({"All quarters": score(d), "Excluding 2020 Q2-Q3": score(d[~covid])}).T
print(tab.round(2))                                    # percentage points
viz_table(tab, digits=2, title="GDPNow vs revised GDP: typical miss about 1.3 points")

#| **The biggest misses**: the pandemic, the 2025 shutdown quarter, and 2015 Q1, which was a near-perfect nowcast of the *advance* estimate (0.2%) that later revisions pushed to 3.6%.
# sort by largest absolute error and show the top 5
print(d.loc[d.error.abs().sort_values(ascending=False).index[:5], ["nowcast", "actual", "error"]].round(2))

#| **Which truth are you scoring against?** The Atlanta Fed reports a 0.76-point average miss against the advance estimate (2011 Q3 to 2026 Q3). BEA reports that growth moves 1.21 points on average from advance to latest (1999–2022).
# three headline numbers: our MAE (excluding COVID), and two published figures typed in by hand
viz_kpi(**{"Our MAE vs latest vintage": round(float(tab.loc["Excluding 2020 Q2-Q3", "MAE"]), 2),
           "Atlanta Fed MAE vs advance": 0.76, "BEA: avg revision, advance to latest": 1.21},
        title="Which truth are you scoring against?")
