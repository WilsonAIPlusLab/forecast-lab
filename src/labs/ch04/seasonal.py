#| **Retail sales, not seasonally adjusted**, from 2012; the test set is January 2024 onward.
import statsmodels.formula.api as smf
retail = fred("RSXFSN", start=2012)          # $ millions, NSA
df = pd.DataFrame({"y": retail})
df["trend"] = np.arange(1, len(df) + 1)
df["month"] = df.index.month                 # 1..12, treated as a category below
df["covid"] = (df.index == "2020-04-01").astype(int)   # pulse dummy: April 2020 only
train, test = df[:"2023-12"], df["2024-01":]

#| **Trend + 11 monthly dummies + the pulse**, fitted to log sales. `C(month)` makes one dummy per month and drops January as the baseline, exactly like `season` in R's `tslm()`.
fit = smf.ols("np.log(y) ~ trend + C(month) + covid", data=train).fit()
print(fit.params.round(4))

#| **Seasonal effects as % gaps from January**: `exp(b) - 1`.
seas = 100 * (np.exp(fit.params.filter(like="C(month)")) - 1)
viz_bars(seas.values, labels=["Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
         sort=False, xlab="% above or below January", title="December sales run about 25% above January")

#| **Forecast the test period** with 80% and 95% prediction intervals, computed in logs and converted back to dollars. Trend and month are known in advance; the COVID dummy is 0.
new = test.assign(covid=0)
p80 = fit.get_prediction(new).summary_frame(alpha=0.20)
p95 = fit.get_prediction(new).summary_frame(alpha=0.05)
fc = np.exp(p80["mean"]).set_axis(test.index)
lo = [np.exp(p80["obs_ci_lower"]).set_axis(test.index), np.exp(p95["obs_ci_lower"]).set_axis(test.index)]
hi = [np.exp(p80["obs_ci_upper"]).set_axis(test.index), np.exp(p95["obs_ci_upper"]).set_axis(test.index)]
viz_forecast(train.y, fc, lo, hi, actual=test.y, levels=("80%", "95%"), from_="2019-01-01",
             fitted=np.exp(fit.fittedvalues)["2019":], title="Trend + seasonal dummies follow the calendar, running a little high")

#| **Scorecard against seasonal naive.** MASE scales by the in-sample seasonal naive error, as in Chapter 3.
sn = pd.Series([train.y.iloc[-12 + (i % 12)] for i in range(len(test))], index=test.index)
scale = (train.y - train.y.shift(12)).abs().mean()
def score(f):
    e = test.y - f
    return {"ME": e.mean(), "MAE": e.abs().mean(), "RMSE": np.sqrt((e**2).mean()),
            "MAPE": 100 * (e / test.y).abs().mean(), "MASE": e.abs().mean() / scale}
scores = pd.DataFrame({"Trend + season regression": score(fc), "Seasonal naive": score(sn)}).T
print(scores.round(3))
viz_table(scores, highlight=["MAE", "RMSE", "MAPE", "MASE"], digits=2, title="Retail sales scorecard, test period 2024 onward")

#| **Breusch–Godfrey test** for autocorrelated residuals (24 lags, as in R's `checkresiduals()`). A tiny p-value says the misses come in runs.
from statsmodels.stats.diagnostic import acorr_breusch_godfrey
lm_stat, lm_p, _, _ = acorr_breusch_godfrey(fit, nlags=24)
print(f"Breusch-Godfrey LM = {lm_stat:.0f}, p-value = {lm_p:.1e}")
