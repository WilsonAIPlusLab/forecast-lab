#| **Setup.** Train on retail sales 2010–2017 (`RSXFSN`, $ millions, NSA), score quantile forecasts on 2018–2019.
import warnings; warnings.filterwarnings("ignore")
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
from scipy.stats import norm
retail = fred("RSXFSN", start=2010)
train, test = retail[:"2017-12"], retail["2018-01":"2019-12"]
taus = [0.1, 0.25, 0.5, 0.75, 0.9]

#| **The pinball loss.** Above the quantile you pay $\tau(y-q)$; below it you pay $(1-\tau)(q-y)$. Lopsided on purpose.
def pinball(y, q, tau):
    return np.where(y >= q, tau * (y - q), (1 - tau) * (q - y))
err = np.arange(-10, 10.5, 0.5)
viz_lines(err, **{"tau = 0.1": pinball(err, 0, 0.1), "tau = 0.5": pinball(err, 0, 0.5), "tau = 0.9": pinball(err, 0, 0.9)},
          xlab="truth minus forecast", ylab="loss", zero=True, title="Pinball loss is lopsided on purpose")

#| **Quantile forecasts.** ETS quantiles come from 2,000 simulated paths of an ETS(M,Ad,M) model. Seasonal naive quantiles use the normal formula with the root mean square of all past seasonal differences (year-over-year changes), widened by $\sqrt{k}$ for $k$ full years ahead (as R's `snaive()` does). The third row copies the ETS point forecast into every quantile.
fit = ETSModel(train, error="mul", trend="add", damped_trend=True, seasonal="mul", seasonal_periods=12).fit(disp=False)
np.random.seed(2026)
paths = fit.simulate(24, repetitions=2000, anchor="end")
q_ets = np.column_stack([paths.quantile(t, axis=1).values for t in taus])
d12 = (train - train.shift(12)).dropna()
sd = np.sqrt(np.mean(d12 ** 2))
sn_mean = np.array([train.iloc[-12 + (i % 12)] for i in range(24)])
k = np.arange(24) // 12 + 1
q_sn = np.column_stack([sn_mean + norm.ppf(t) * sd * np.sqrt(k) for t in taus])
q_pt = np.tile(fit.forecast(24).values[:, None], (1, len(taus)))

#| **Score them.** Average pinball loss per $\tau$, then across $\tau$ (approximately half the **CRPS**). Lower is better.
y = test.values
score = lambda Q: [pinball(y, Q[:, j], t).mean() for j, t in enumerate(taus)]
tab = pd.DataFrame([score(q_ets), score(q_sn), score(q_pt)], columns=[f"tau={t}" for t in taus],
                   index=["ETS quantiles", "Seasonal naive quantiles", "ETS point forecast only"])
tab["Average"] = tab.mean(axis=1)
print(tab.round(0))
viz_table(tab, digits=0, highlight=list(tab.columns), title="Pinball loss ($ millions): honest quantiles beat a point forecast")

#| **Does each quantile do its job?** The share of months with the truth below each quantile should be close to $\tau$. Here the truth ran high: 2018–2019 sales grew faster than the model expected, so every quantile sat too low.
print(pd.DataFrame({"target": taus, "ETS": (y[:, None] <= q_ets).mean(axis=0)}).round(2).T)
