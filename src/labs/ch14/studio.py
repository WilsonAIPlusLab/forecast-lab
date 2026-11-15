#| **The configuration**, identical to the R lab: U.S. retail sales excluding food services (`RSXFSN`, **not seasonally adjusted**) in **$ billions**, January 2010 to the latest month, 12 months ahead, evaluated at **12 forecast origins**, one every four months over the last four years.
import warnings; warnings.filterwarnings("ignore")     # hide optimizer warnings
from statsmodels.tsa.holtwinters import ExponentialSmoothing   # Holt-Winters exponential smoothing
from statsmodels.tsa.statespace.sarimax import SARIMAX         # seasonal ARIMA
y = fred("RSXFSN", start=2010) / 1000                  # monthly retail sales, $ billions, not SA
y.index.freq = "MS"                                    # tell pandas the data are monthly (month-start dates)
h, n = 12, len(y)                                      # forecast 12 months ahead; n = number of months
origins = list(range(n - 48, n - 3, 4))                # 12 origins: every 4th month of the last four years

#| **Four forecasting functions, each re-fitted on the data up to the origin.** Python has no automatic `ets()`/`auto.arima()` search built in, so we use the forms R chose from the data *before the first origin*: damped-trend Holt-Winters with multiplicative seasonality (statsmodels' closest fast equivalent of ETS(M,Ad,M)) and ARIMA(0,1,2)(0,1,1)[12]. The ARIMA fit starts from the previous origin's estimates, which only speeds up the optimizer; the estimates themselves use data up to the origin alone.
warm = {"p": None}                                     # remembers the last ARIMA estimates (a warm start)
# seasonal naive: repeat the last 12 months (same month last year)
def f_snaive(tr): return np.array([tr.iloc[-12 + (i % 12)] for i in range(h)])
# drift: last value + average monthly change x steps ahead (line from first to last point)
def f_drift(tr):  return tr.iloc[-1] + (tr.iloc[-1] - tr.iloc[0]) / (len(tr) - 1) * np.arange(1, h + 1)
# ETS(M,Ad,M) stand-in: damped trend, multiplicative seasonality
def f_ets(tr):
    return ExponentialSmoothing(tr, trend="add", damped_trend=True, seasonal="mul",
                                seasonal_periods=12).fit(use_brute=False).forecast(h).values
def f_arima(tr):
    # ARIMA(0,1,2)(0,1,1)[12], starting the optimizer from the previous estimates
    r = SARIMAX(tr, order=(0, 1, 2), seasonal_order=(0, 1, 1, 12)).fit(disp=False, start_params=warm["p"])
    warm["p"] = r.params                               # save for the next origin
    return r.forecast(h).values
methods = {"Seasonal naive": f_snaive, "Drift": f_drift, "ETS": f_ets, "ARIMA": f_arima}   # name -> function

#| **Rolling-origin evaluation by hand**, the same loop as the R lab: at each origin, re-fit on `y[:o]`, forecast 12 months, and store actual minus forecast (`NaN` past the end of the data). The combination's errors are the average of the ETS and ARIMA errors.
errs = {k: np.full((len(origins), h), np.nan) for k in methods}   # per method: rows = origins, cols = horizons
for r, o in enumerate(origins):                        # r = row number, o = origin position
    for k, f in methods.items():
        fc = f(y.iloc[:o])                             # re-fit on the first o months only
        for j in range(min(h, n - o)):                 # skip horizons past the end of the data
            errs[k][r, j] = y.iloc[o + j] - fc[j]      # error = actual minus forecast
errs["Combination"] = (errs["ETS"] + errs["ARIMA"]) / 2   # averaging forecasts = averaging their errors

#| **The scorecard**, averaged over horizons 1 to 12 like the Studio. MASE divides by the in-sample seasonal naive MAE.
# MAE by horizon (rows 1..12) for each method (columns); nanmean skips the NaN gaps
mae_h = pd.DataFrame({k: np.nanmean(np.abs(e), axis=0) for k, e in errs.items()}, index=range(1, h + 1))
scale = (y - y.shift(12)).abs().mean()                 # seasonal naive in-sample MAE (lag-12 differences)
score = pd.DataFrame({"MAE": mae_h.mean(),             # average over the 12 horizons
                      "RMSE": pd.Series({k: np.sqrt(np.nanmean(e**2, axis=0)).mean() for k, e in errs.items()}),
                      "MASE": mae_h.mean() / scale,
                      "Bias": pd.Series({k: np.nanmean(e) for k, e in errs.items()})})   # mean error (+ = too low)
best = score["MAE"].idxmin()                           # name of the method with the lowest MAE
print(score.round(2))
viz_table(score, highlight=["MAE", "RMSE", "MASE"], digits=2, title=f"{best} wins on 12 rolling origins ($ billions)")
# MAE by horizon for four methods (drift left out); ** unpacks the dict into named lines
viz_lines(range(1, h + 1), **{k: mae_h[k] for k in ["Seasonal naive", "ETS", "ARIMA", "Combination"]},
          xlab="months ahead", ylab="MAE ($ billions)", zero=True, title="The models' edge over seasonal naive shrinks as the horizon grows")

#| **Fan chart with ranges from past errors**: re-fit the best method on all the data, then add the 10th/25th/75th/90th percentiles of its errors at each horizon (rough, with only 10 to 12 errors per horizon).
idx = pd.date_range(y.index[-1] + pd.offsets.MonthBegin(1), periods=h, freq="MS")   # the 12 future months
final = {k: f(y) for k, f in methods.items()}          # final forecasts from all the data
final["Combination"] = (final["ETS"] + final["ARIMA"]) / 2
point = pd.Series(final[best], index=idx)              # best method's point forecasts
q = {p: np.nanquantile(errs[best], p, axis=0) for p in (.10, .25, .75, .90)}   # error percentiles per horizon
# 50% and 80% bands
viz_forecast(y, point, lower=[point + q[.25], point + q[.10]], upper=[point + q[.75], point + q[.90]],
             levels=("50%", "80%"), method=best, from_="2020",
             title=f"Retail sales: about ${point.iloc[-1]:.0f} billion by {idx[-1]:%B %Y}")

#| **The executive summary**, generated with an f-string. Every number comes from the code above.
lo80, hi80 = point.iloc[-1] + q[.10][-1], point.iloc[-1] + q[.90][-1]   # 80% range at the 12-month horizon
gain = 100 * (1 - score.loc[best, "MAE"] / score.loc["Seasonal naive", "MAE"])   # % MAE gain over seasonal naive
print(f"We expect U.S. retail sales excluding food services (not seasonally adjusted) to be about "
      f"${point.iloc[-1]:.1f} billion in {idx[-1]:%B %Y} (80% range ${lo80:.1f} to ${hi80:.1f} billion). "
      f"Over {len(origins)} forecast origins in the past four years, the most accurate method was {best}, with a typical miss of "
      f"${mae_h[best].iloc[0]:.1f} billion one month ahead and ${mae_h[best].iloc[-1]:.1f} billion {h} months ahead, "
      f"{gain:.0f}% smaller than the seasonal naive rule.")
