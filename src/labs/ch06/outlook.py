#| **Model the price level, report inflation.** Log core PCE prices (monthly, SA, 2000 onward); a forecast of the log level converts exactly into a forecast of 12-month inflation.
import warnings
from statsmodels.tsa.arima.model import ARIMA                    # ARIMA models
from statsmodels.tsa.holtwinters import ExponentialSmoothing     # Holt's linear trend method
warnings.filterwarnings("ignore")                                # hide optimizer warnings from hundreds of refits
pce = fred("PCEPILFE", start=2000)                               # core PCE price index, monthly
lp = np.log(pce)                                                 # log price level: the series we model
yoy = 100 * (pce / pce.shift(12) - 1)                            # 12-month inflation, %; .shift(12) = value 12 months earlier

#| **Three contenders and a benchmark**, the same as the R tab. In statsmodels, `trend="t"` with d = 1 is the drift term, and Holt's method stands in for ETS(A,A,N) (same point forecasts, different estimation details).
# Each model is a function(y, h) that returns h forecasts of log prices made from history y
def f_bench(y, h): return y.iloc[-1] + np.arange(1, h + 1) * (y.iloc[-1] - y.iloc[-13]) / 12   # extend last year's average monthly change
def f_021(y, h):   return ARIMA(y.values, order=(0, 2, 1)).fit().forecast(h)
def f_111d(y, h):  return ARIMA(y.values, order=(1, 1, 1), trend="t").fit().forecast(h)        # with drift
def f_ets(y, h):   return ExponentialSmoothing(y.values, trend="add").fit().forecast(h)        # Holt, undamped
models = {"Last 12 months (benchmark)": f_bench, "ARIMA(0,2,1)": f_021,
          "ARIMA(1,1,1) + drift": f_111d, "ETS(A,A,N)": f_ets}

#| **Rolling origins**: every December from 2010 to 2024 (15 origins). The R tab uses every June *and* December (31 origins); statsmodels refits are slower in the browser, so we halve the work here. Refit, forecast 12 months, record the 12-month-inflation error in percentage points (actual minus forecast).
y = lp.values                                                    # plain NumPy array of log prices
# list comprehension: positions i of every December from 2010 that still leave 12 months to check
origins = [i for i, d in enumerate(lp.index) if d.year >= 2010 and d.month == 12 and i <= len(y) - 13]
# For model m: one row per origin, one column per horizon (1-12) of 12-month-inflation errors
def yoy_err(m):
    out = []
    for o in origins:
        f = np.asarray(m(lp.iloc[:o + 1], 12)); i = np.arange(o + 1, o + 13)   # refit on data up to origin; i = the 12 target months
        out.append(100 * (np.exp(y[i] - y[i - 12]) - 1) - 100 * (np.exp(f - y[i - 12]) - 1))   # actual minus forecast
    return np.array(out)
E = {k: yoy_err(m) for k, m in models.items()}                   # error matrix for every model
pre = np.array([lp.index[o].year < 2020 for o in origins])       # True for origins before 2020

#| **The scorecard.** Expect a near tie between ARIMA(0,2,1) and ETS (MAE about 0.59), both a little ahead of the benchmark (0.62). With only 15 December origins, the mean-reverting ARIMA(1,1,1) falls just *behind* the benchmark here, a reminder of how noisy a short scorecard is. Other small differences from R come from the estimators (statsmodels uses exact likelihood throughout).
# Column 11 (Python counts from 0) = the 12-months-ahead error; ~pre flips True/False to select 2020-on origins
score = pd.DataFrame({k: {"MAE": np.abs(e[:, 11]).mean(), "RMSE": np.sqrt((e[:, 11] ** 2).mean()), "ME": e[:, 11].mean(),
                          "MAE before 2020": np.abs(e[pre, 11]).mean(), "MAE 2020 on": np.abs(e[~pre, 11]).mean()}
                      for k, e in E.items()}).T                  # .T transposes: one row per model
print(score.round(3))
viz_table(score, highlight=["MAE", "RMSE"], digits=2,            # green = lowest error in each column
          title="12-month-ahead inflation errors (pp): ARIMA and ETS tie, both edge out the benchmark")

#| **Error by horizon.**
# mean absolute error at each horizon 1-12 (average down the rows, axis=0), one line per model
viz_lines(range(1, 13), **{k: np.abs(e).mean(axis=0) for k, e in E.items()}, xlab="months ahead",
          ylab="MAE (percentage points)", zero=True, title="Errors grow with the horizon, and the models stay bunched together")

#| **The fan chart.** Forecast log prices with ARIMA(0,2,1), then convert the mean and each interval bound to 12-month inflation using the already-observed base months.
res = ARIMA(lp, order=(0, 2, 1)).fit()                           # same model auto.arima() picks in R
pred = res.get_forecast(12)                                      # 12-month forecast object (mean + intervals)
base = lp.iloc[-12:].values                                      # last 12 observed log prices: the base month of each rate
# convert forecast log prices to 12-month inflation (%), dated like the forecast
to_yoy = lambda v: pd.Series(100 * (np.exp(np.asarray(v) - base) - 1), index=pred.predicted_mean.index)
ci80, ci95 = pred.conf_int(alpha=0.20), pred.conf_int(alpha=0.05)   # 80% and 95% intervals (column 0 = lower, 1 = upper)
mean = to_yoy(pred.predicted_mean)                               # point forecast of 12-month inflation
viz_forecast(yoy["2016":], mean, lower=[to_yoy(ci80.iloc[:, 0]), to_yoy(ci95.iloc[:, 0])],
             upper=[to_yoy(ci80.iloc[:, 1]), to_yoy(ci95.iloc[:, 1])], levels=("80%", "95%"),
             method="ARIMA(0,2,1) on log core PCE",
             title="Core PCE inflation is expected to stay near 3% over the next 12 months")

#| **The numbers for your memo.**
mr = ARIMA(lp.values, order=(1, 1, 1), trend="t").fit().forecast(12)   # mean-reverting alternative
# f-strings like f"{x:.1f}%" format a number with 1 decimal and a % sign
viz_kpi(title="Core PCE inflation outlook", **{"Latest 12-month rate": f"{yoy.iloc[-1]:.1f}%",
        "Forecast, 12 months out": f"{mean.iloc[-1]:.1f}%",
        "80% interval": f"{to_yoy(ci80.iloc[:, 0]).iloc[-1]:.1f}% to {to_yoy(ci80.iloc[:, 1]).iloc[-1]:.1f}%",
        "Mean-reverting model": f"{100 * (np.exp(mr[-1] - base[-1]) - 1):.1f}%"})
print(mean.round(2).tail(3))                                     # last three forecast months
