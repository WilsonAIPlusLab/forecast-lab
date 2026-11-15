#| **The configuration**, identical to the R lab: U.S. retail sales excluding food services (`RSXFSN`, **not seasonally adjusted**) in **$ billions**, January 2010 to the latest month, 12 months ahead, evaluated at **12 forecast origins**, one every four months over the last four years.
import warnings; warnings.filterwarnings("ignore")
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from statsmodels.tsa.statespace.sarimax import SARIMAX
y = fred("RSXFSN", start=2010) / 1000
y.index.freq = "MS"
h, n = 12, len(y)
origins = list(range(n - 48, n - 3, 4))

#| **Four forecasting functions, each re-fitted on the data up to the origin.** Python has no automatic `ets()`/`auto.arima()` search built in, so we use the forms R chose from the data *before the first origin*: damped-trend Holt-Winters with multiplicative seasonality (statsmodels' closest fast equivalent of ETS(M,Ad,M)) and ARIMA(0,1,2)(0,1,1)[12]. The ARIMA fit starts from the previous origin's estimates, which only speeds up the optimizer; the estimates themselves use data up to the origin alone.
warm = {"p": None}
def f_snaive(tr): return np.array([tr.iloc[-12 + (i % 12)] for i in range(h)])
def f_drift(tr):  return tr.iloc[-1] + (tr.iloc[-1] - tr.iloc[0]) / (len(tr) - 1) * np.arange(1, h + 1)
def f_ets(tr):
    return ExponentialSmoothing(tr, trend="add", damped_trend=True, seasonal="mul",
                                seasonal_periods=12).fit(use_brute=False).forecast(h).values
def f_arima(tr):
    r = SARIMAX(tr, order=(0, 1, 2), seasonal_order=(0, 1, 1, 12)).fit(disp=False, start_params=warm["p"])
    warm["p"] = r.params
    return r.forecast(h).values
methods = {"Seasonal naive": f_snaive, "Drift": f_drift, "ETS": f_ets, "ARIMA": f_arima}

#| **Rolling-origin evaluation by hand**, the same loop as the R lab: at each origin, re-fit on `y[:o]`, forecast 12 months, and store actual minus forecast (`NaN` past the end of the data). The combination's errors are the average of the ETS and ARIMA errors.
errs = {k: np.full((len(origins), h), np.nan) for k in methods}
for r, o in enumerate(origins):
    for k, f in methods.items():
        fc = f(y.iloc[:o])
        for j in range(min(h, n - o)):
            errs[k][r, j] = y.iloc[o + j] - fc[j]
errs["Combination"] = (errs["ETS"] + errs["ARIMA"]) / 2

#| **The scorecard**, averaged over horizons 1 to 12 like the Studio. MASE divides by the in-sample seasonal naive MAE.
mae_h = pd.DataFrame({k: np.nanmean(np.abs(e), axis=0) for k, e in errs.items()}, index=range(1, h + 1))
scale = (y - y.shift(12)).abs().mean()
score = pd.DataFrame({"MAE": mae_h.mean(),
                      "RMSE": pd.Series({k: np.sqrt(np.nanmean(e**2, axis=0)).mean() for k, e in errs.items()}),
                      "MASE": mae_h.mean() / scale,
                      "Bias": pd.Series({k: np.nanmean(e) for k, e in errs.items()})})
best = score["MAE"].idxmin()
print(score.round(2))
viz_table(score, highlight=["MAE", "RMSE", "MASE"], digits=2, title=f"{best} wins on 12 rolling origins ($ billions)")
viz_lines(range(1, h + 1), **{k: mae_h[k] for k in ["Seasonal naive", "ETS", "ARIMA", "Combination"]},
          xlab="months ahead", ylab="MAE ($ billions)", zero=True, title="The models' edge over seasonal naive shrinks as the horizon grows")

#| **Fan chart with ranges from past errors**: re-fit the best method on all the data, then add the 10th/25th/75th/90th percentiles of its errors at each horizon (rough, with only 10 to 12 errors per horizon).
idx = pd.date_range(y.index[-1] + pd.offsets.MonthBegin(1), periods=h, freq="MS")
final = {k: f(y) for k, f in methods.items()}
final["Combination"] = (final["ETS"] + final["ARIMA"]) / 2
point = pd.Series(final[best], index=idx)
q = {p: np.nanquantile(errs[best], p, axis=0) for p in (.10, .25, .75, .90)}
viz_forecast(y, point, lower=[point + q[.25], point + q[.10]], upper=[point + q[.75], point + q[.90]],
             levels=("50%", "80%"), method=best, from_="2020",
             title=f"Retail sales: about ${point.iloc[-1]:.0f} billion by {idx[-1]:%B %Y}")

#| **The executive summary**, generated with an f-string. Every number comes from the code above.
lo80, hi80 = point.iloc[-1] + q[.10][-1], point.iloc[-1] + q[.90][-1]
gain = 100 * (1 - score.loc[best, "MAE"] / score.loc["Seasonal naive", "MAE"])
print(f"We expect U.S. retail sales excluding food services (not seasonally adjusted) to be about "
      f"${point.iloc[-1]:.1f} billion in {idx[-1]:%B %Y} (80% range ${lo80:.1f} to ${hi80:.1f} billion). "
      f"Over {len(origins)} forecast origins in the past four years, the most accurate method was {best}, with a typical miss of "
      f"${mae_h[best].iloc[0]:.1f} billion one month ahead and ${mae_h[best].iloc[-1]:.1f} billion {h} months ahead, "
      f"{gain:.0f}% smaller than the seasonal naive rule.")
