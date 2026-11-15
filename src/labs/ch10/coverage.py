#| **The question.** Does an 80% interval contain the truth 80% of the time? Check it with a **rolling forecast origin**: stand at every month from December 2014 to July 2026, forecast, and wait to see. Data: retail sales from 2005 (`RSXFSN`, $ millions, NSA).
import warnings; warnings.filterwarnings("ignore")
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
retail = fred("RSXFSN", start=2005)
origins = pd.date_range("2014-12-01", "2026-07-01", freq="MS")
spec = dict(error="mul", trend="add", seasonal="mul", seasonal_periods=12)
len(origins)

#| **Re-estimate once a year.** At each December origin we fit ETS(M,A,M) on the data so far. Then `.smooth(params)` runs that model, with those parameters, through the whole series. The model's state at any month depends only on data up to that month, so one smoothing pass serves all twelve origins of the coming year (the same idea as R's `use.initial.values = TRUE`).
yearly = {}
for o in origins[origins.month == 12]:
    params = ETSModel(retail[:o], **spec).fit(disp=False).params
    yearly[o.year] = ETSModel(retail, **spec).smooth(params)

#| **The audit loop.** At each origin `o`, estimate the error scale $\sigma$ from the one-step errors *up to `o` only* (using the whole series here would leak the future, including COVID, into 2015's intervals). Simulate 1,000 paths for the next 12 months with those normal errors (`anchor=o` starts right after month `o`), take percentiles 2.5, 10, 90 and 97.5 as the 95% and 80% limits, and record whether the truth 1 and 12 months later fell inside. These are simulation-based intervals, so results differ slightly from R's formula intervals.
np.random.seed(1)
rows = []
for o in origins:
    res = yearly[o.year if o.month == 12 else o.year - 1]
    rel_err = (retail / res.fittedvalues - 1)[:o]            # relative one-step errors so far
    sigma = np.sqrt(np.mean(rel_err ** 2))
    sims = res.simulate(12, anchor=o, repetitions=1000, random_errors=np.random.normal(0, sigma, (12, 1000))).values
    q = np.quantile(sims, [0.025, 0.10, 0.90, 0.975], axis=1)
    for k in (1, 12):
        t = o + pd.DateOffset(months=k)
        if t in retail.index:
            rows.append(dict(h=k, date=t, actual=retail[t], lo95=q[0, k - 1], lo80=q[1, k - 1], hi80=q[2, k - 1], hi95=q[3, k - 1]))
audit = pd.DataFrame(rows)
audit["in80"] = audit.actual.between(audit.lo80, audit.hi80)
audit["in95"] = audit.actual.between(audit.lo95, audit.hi95)
len(audit)

#| **Overall coverage**, in percent. Compare with the promises of 80 and 95.
print((100 * audit.groupby("h")[["in80", "in95"]].mean()).round(1))

#| **By era.** Too narrow in the 2020–2021 crisis, too wide in calm years. Being right on average can hide being wrong in both directions.
audit["era"] = pd.cut(audit.date.dt.year, [0, 2019, 2021, 3000], labels=["2015-2019", "2020-2021", "2022-2026"])
by_era = (100 * audit.groupby(["era", "h"], observed=True)[["in80", "in95"]].mean()).round(1).reset_index()
by_era.columns = ["era", "h", "80% interval", "95% interval"]
print(by_era)
viz_table(by_era, digits=1, title="Coverage (%) by era: too narrow in the crisis, too wide after it")

#| **The audit strip.** Green = inside the 80% interval, red = outside. Misses come in clusters.
strip = lambda d: dict(date=[x.strftime("%Y-%m-%d") for x in d.date], inside=d.in80.tolist())
viz_custom("ch10-strip", title="80% intervals for retail sales: misses come in clusters", nominal=80,
           rows=[dict(name="1 month ahead", **strip(audit[audit.h == 1])), dict(name="12 months ahead", **strip(audit[audit.h == 12]))])
