#| **Setup.** Train on retail sales 2010–2017 (`RSXFSN`, $ millions, NSA), score quantile forecasts on 2018–2019.
import warnings; warnings.filterwarnings("ignore")   # hide statsmodels fitting warnings
from statsmodels.tsa.exponential_smoothing.ets import ETSModel   # exponential smoothing (ETS)
from scipy.stats import norm                  # normal distribution (quantiles via norm.ppf)
retail = fred("RSXFSN", start=2010)           # monthly U.S. retail sales, $ millions, not seasonally adjusted
train, test = retail[:"2017-12"], retail["2018-01":"2019-12"]   # train 2010-2017, test 2018-2019 (24 months)
taus = [0.1, 0.25, 0.5, 0.75, 0.9]            # quantile levels (tau) to forecast

#| **The pinball loss.** Above the quantile you pay $\tau(y-q)$; below it you pay $(1-\tau)(q-y)$. Lopsided on purpose.
def pinball(y, q, tau):
    # np.where(test, if True, if False), element by element
    return np.where(y >= q, tau * (y - q), (1 - tau) * (q - y))
err = np.arange(-10, 10.5, 0.5)               # truth minus forecast, -10 to 10
viz_lines(err, **{"tau = 0.1": pinball(err, 0, 0.1), "tau = 0.5": pinball(err, 0, 0.5), "tau = 0.9": pinball(err, 0, 0.9)},
          xlab="truth minus forecast", ylab="loss", zero=True, title="Pinball loss is lopsided on purpose")

#| **Quantile forecasts.** ETS quantiles come from 2,000 simulated paths of an ETS(M,Ad,M) model. Seasonal naive quantiles use the normal formula with the root mean square of all past seasonal differences (year-over-year changes), widened by $\sqrt{k}$ for $k$ full years ahead (as R's `snaive()` does). The third row copies the ETS point forecast into every quantile.
# ETS(M,Ad,M)
fit = ETSModel(train, error="mul", trend="add", damped_trend=True, seasonal="mul", seasonal_periods=12).fit(disp=False)
np.random.seed(2026)                          # fix the random draws so results repeat exactly
paths = fit.simulate(24, repetitions=2000, anchor="end")   # 24 months x 2,000 simulated futures
q_ets = np.column_stack([paths.quantile(t, axis=1).values for t in taus])   # per month, the tau quantiles (24 x 5)
d12 = (train - train.shift(12)).dropna()      # .shift(12) = value a year earlier, so d12 = year-over-year changes
sd = np.sqrt(np.mean(d12 ** 2))               # root mean square of those changes
sn_mean = np.array([train.iloc[-12 + (i % 12)] for i in range(24)])   # seasonal naive: repeat the last 12 months
k = np.arange(24) // 12 + 1                   # full years ahead: 1 for months 1-12, 2 for months 13-24
# normal quantiles, widened by sqrt(k)
q_sn = np.column_stack([sn_mean + norm.ppf(t) * sd * np.sqrt(k) for t in taus])
q_pt = np.tile(fit.forecast(24).values[:, None], (1, len(taus)))   # point forecast repeated in all 5 columns

#| **Score them.** Average pinball loss per $\tau$, then across $\tau$ (approximately half the **CRPS**). Lower is better.
y = test.values                               # test data as a plain array
score = lambda Q: [pinball(y, Q[:, j], t).mean() for j, t in enumerate(taus)]   # mean loss per tau
tab = pd.DataFrame([score(q_ets), score(q_sn), score(q_pt)], columns=[f"tau={t}" for t in taus],
                   index=["ETS quantiles", "Seasonal naive quantiles", "ETS point forecast only"])
tab["Average"] = tab.mean(axis=1)             # average across tau, about half the CRPS
print(tab.round(0))                           # $ millions; lower is better
viz_table(tab, digits=0, highlight=list(tab.columns), title="Pinball loss ($ millions): honest quantiles beat a point forecast")

#| **Does each quantile do its job?** The share of months with the truth below each quantile should be close to $\tau$. Here the truth ran high: 2018–2019 sales grew faster than the model expected, so every quantile sat too low.
# y[:, None] turns y into a column so it compares against every tau column; mean = share at or below
print(pd.DataFrame({"target": taus, "ETS": (y[:, None] <= q_ets).mean(axis=0)}).round(2).T)
