#| **Load and split in time.** U.S. e-commerce sales, $ millions, **not seasonally adjusted**. Train through August 2025; the 12 months after that are the test set.
import warnings; warnings.filterwarnings("ignore")
from statsmodels.tsa.holtwinters import SimpleExpSmoothing, Holt, ExponentialSmoothing
online = fred("MRTSSM4541USN", start=2015)
train = online[:"2025-08"]
test = online["2025-09":]
h = len(test)

#| **SES with α = 0.3.** `SimpleExpSmoothing` keeps only a level. The forecast is flat.
f_ses = SimpleExpSmoothing(train, initialization_method="estimated").fit(smoothing_level=0.3, optimized=False).forecast(h)
print(f_ses.round().head(3))

#| **Holt (linear trend) and damped Holt.** Same α and β as the R lab; the damped version uses φ = 0.9. statsmodels estimates the starting level and slope differently from R's `holt()`, so Holt's score below differs from the R tab (MASE about 1.05 here, 1.25 in R). The lesson is the same: without a seasonal component, no method beats seasonal naive.
f_holt = Holt(train, initialization_method="estimated").fit(smoothing_level=0.3, smoothing_trend=0.05, optimized=False).forecast(h)
f_damped = Holt(train, damped_trend=True, initialization_method="estimated").fit(
    smoothing_level=0.3, smoothing_trend=0.05, damping_trend=0.9, optimized=False).forecast(h)

#| **Holt-Winters with multiplicative seasonality.** statsmodels estimates α, β, γ by minimizing squared errors, while R's `hw()` maximizes the likelihood, so the parameters (and the scores below) differ slightly from the R tab.
hw_fit = ExponentialSmoothing(train, trend="add", seasonal="mul", seasonal_periods=12,
                              initialization_method="estimated").fit()
f_hw = hw_fit.forecast(h)
print({k: round(hw_fit.params[k], 3) for k in ["smoothing_level", "smoothing_trend", "smoothing_seasonal"]})

#| **Plot against the truth.**
viz_compare(history=train["2021":], actual=test, SES=f_ses, Holt=f_holt,
            **{"Damped Holt": f_damped, "Holt-Winters (mult.)": f_hw},
            title="Only Holt-Winters follows the holiday peak")

#| **Score them.** MASE uses the in-sample MAE of seasonal naive as the yardstick.
scale = (train - train.shift(12)).abs().mean()
f_sn = pd.Series(train.iloc[-12:].values, index=test.index)
def score(f):
    e = test - f.values
    return {"ME": e.mean(), "MAE": e.abs().mean(), "RMSE": np.sqrt((e**2).mean()),
            "MAPE": 100 * (e / test).abs().mean(), "MASE": e.abs().mean() / scale}
scores = pd.DataFrame({k: score(v) for k, v in {"SES": f_ses, "Holt": f_holt, "Damped Holt": f_damped,
                       "Holt-Winters (mult.)": f_hw, "Seasonal naive": f_sn}.items()}).T
print(scores.round(2))
viz_table(scores, highlight=["MAE", "RMSE", "MAPE", "MASE"], digits=2,
          title="Only the seasonal method beats seasonal naive")
