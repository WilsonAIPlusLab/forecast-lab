#| **Fit once, then forecast one month at a time.** Fit ETS(M,Ad,M) on retail sales 2000–2009 (`RSXFSN`, $ millions, NSA), the model R's `ets()` picks. `.smooth(params)` runs the same model, with the same parameters, through all later data; its fitted values are genuine one-step-ahead forecasts.
import warnings; warnings.filterwarnings("ignore")   # hide statsmodels fitting warnings
from statsmodels.tsa.exponential_smoothing.ets import ETSModel   # exponential smoothing (ETS)
from scipy.stats import norm                  # normal distribution (for z)
retail = fred("RSXFSN", start=2000)           # monthly U.S. retail sales, $ millions, not seasonally adjusted
# ETS(M,Ad,M) settings
spec = dict(error="mul", trend="add", damped_trend=True, seasonal="mul", seasonal_periods=12)
train = retail[:"2009-12"]                    # estimation period: 2000-2009
fit = ETSModel(train, **spec).fit(disp=False) # estimate on 2000-2009 only; **spec unpacks the settings
# same fixed model run through all data: one-step forecasts
onestep = ETSModel(retail, **spec).smooth(fit.params).fittedvalues

#| **Nonconformity scores**: absolute errors in percent of the forecast.
score = (retail - onestep).abs() / onestep    # relative absolute error each month

#| **Split conformal, once.** Calibrate on the 36 months of 2016–2018: $q$ is the $\lceil (n+1)(1-\alpha) \rceil$-th smallest score.
alpha = 0.2                                   # miss rate allowed: 1 - 0.2 = 80% interval
cal = score["2016":"2018"].values             # calibration scores: Jan 2016 to Dec 2018
n = len(cal)                                  # 36 calibration months
# conformal cutoff: the 30th smallest (- 1 since Python counts from 0)
q = np.sort(cal)[int(np.ceil((n + 1) * (1 - alpha))) - 1]
print(n, round(100 * q, 2))                   # q in percent: the band is forecast x (1 +/- q)
# histogram of past misses
viz_custom("ch10-hist", values=(100 * cal).tolist(), bins=18, xlab="calibration error (% of forecast)",
           markers=[dict(x=100 * q, label="80% conformal cutoff")],
           title=f"80% of past misses were smaller than {100 * q:.1f}%, so the band is ±{100 * q:.1f}%")

#| **Apply it to 2019.**
in19 = score["2019"] <= q                     # inside the band if the miss is no bigger than q
print(int(in19.sum()), "of", len(in19), "months inside")   # sum() of True/False counts the Trues

#| **Rolling conformal vs. the frozen formula.** Every month, recalibrate on the last 36 errors. The formula interval is forecast $\times(1 \pm z\sigma)$ with $\sigma$ estimated on 2000–2009.
K, z = 36, norm.ppf(1 - alpha / 2)            # window length; normal z for 80% (about 1.28)
sig = np.sqrt(np.mean((train / fit.fittedvalues - 1) ** 2))   # model's sigma from 2000-2009 relative errors
s = score.values                              # plain numpy array of scores
idx = np.where(retail.index >= "2013-01-01")[0]   # positions of the months evaluated, 2013 onward
k = int(np.ceil((K + 1) * (1 - alpha))) - 1   # which sorted score is the cutoff (0-based)
# rolling conformal: cutoff from the previous K scores
conf_in = np.array([s[i] <= np.sort(s[i - K:i])[k] for i in idx])
form_in = s[idx] <= z * sig                   # frozen formula: inside if the miss is within z x sigma
# pd.cut bins years into eras: (0, 2019], (2019, 2021], (2021, 3000]
era = pd.cut(retail.index[idx].year, [0, 2019, 2021, 3000], labels=["2013-2019", "2020-2021", "2022-2026"])
# coverage share per era for each method; .T = one row per method
tab = pd.DataFrame({"Model formula": pd.Series(form_in).groupby(era, observed=True).mean(),
                    "Rolling conformal": pd.Series(conf_in).groupby(era, observed=True).mean()}).T
tab.insert(0, "All", [form_in.mean(), conf_in.mean()])   # overall coverage as the first column
print((100 * tab).round(1))                   # coverage in %; the promise is 80
viz_table(100 * tab, digits=1, title="80% intervals, actual coverage (%): conformal is closer to 80 overall and far closer in the crisis")

#| **Where each method missed.** Red cells are misses.
d = [x.strftime("%Y-%m-%d") for x in retail.index[idx]]   # dates of the evaluated months, as text
# one strip row per method
viz_custom("ch10-strip", title="Rolling conformal recovers after shocks; the frozen formula does not", nominal=80,
           rows=[dict(name="Model formula", date=d, inside=form_in.tolist()), dict(name="Rolling conformal", date=d, inside=conf_in.tolist())])
