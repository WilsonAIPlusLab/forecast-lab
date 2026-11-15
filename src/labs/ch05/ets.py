#| **Same data, same split.** E-commerce sales ($ millions, NSA), training through August 2025.
import warnings; warnings.filterwarnings("ignore")
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
online = fred("MRTSSM4541USN", start=2015)
train = online[:"2025-08"]
test = online["2025-09":]

#| **Automatic selection, by hand.** statsmodels has no `ets()` that searches for you, so we write the search: fit each candidate by maximum likelihood and keep the lowest **AICc**. (Additive-error models with multiplicative seasons are left out, as R does. statsmodels drops a constant from the likelihood, so its AICc values are on a different scale from R's; only the differences matter.)
cands = {"ANA": ("add", None, False, "add"), "AAA": ("add", "add", False, "add"),
         "AAdA": ("add", "add", True, "add"), "MNM": ("mul", None, False, "mul"),
         "MAM": ("mul", "add", False, "mul"), "MAdM": ("mul", "add", True, "mul")}
fits = {}
for name, (e, t, d, s) in cands.items():
    fits[name] = ETSModel(train, error=e, trend=t, damped_trend=d, seasonal=s, seasonal_periods=12).fit(disp=False)
aicc = pd.Series({k: f.aicc for k, f in fits.items()}).sort_values()
print(aicc.round(0))

#| **The winner and its parameters.** α, β, γ play the same role as in R. Estimates differ a little from R's because the optimizers and starting values differ.
best = aicc.index[0]
fit = fits[best]
label = {"ANA": "ETS(A,N,A)", "AAA": "ETS(A,A,A)", "AAdA": "ETS(A,Ad,A)", "MNM": "ETS(M,N,M)", "MAM": "ETS(M,A,M)", "MAdM": "ETS(M,Ad,M)"}[best]
print(label, {k: round(v, 3) for k, v in zip(fit.param_names, fit.params) if k.startswith("smoothing")})

#| **Forecast with 80% and 95% prediction intervals** from the state-space model.
pred = fit.get_prediction(start=test.index[0], end=test.index[-1])
f80, f95 = pred.summary_frame(alpha=0.20), pred.summary_frame(alpha=0.05)
viz_forecast(train["2021":], f95["mean"], lower=[f80["pi_lower"], f95["pi_lower"]], upper=[f80["pi_upper"], f95["pi_upper"]],
             levels=("80%", "95%"), actual=test, method=label,
             title="All 12 test months land inside the 95% interval")

#| **Did the intervals hold?** Count test months inside the 95% interval, and score the point forecast.
inside = ((test >= f95["pi_lower"]) & (test <= f95["pi_upper"])).sum()
scale = (train - train.shift(12)).abs().mean()
e = test - f95["mean"]
print("inside 95%:", inside, "| MAPE:", round(100 * (e / test).abs().mean(), 2), "| MASE:", round(e.abs().mean() / scale, 2))
