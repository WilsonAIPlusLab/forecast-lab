import warnings; warnings.filterwarnings("ignore")   # hide optimizer warnings
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
food = fred("MRTSSM722USN", start=2015)          # food services & drinking places, $ millions, NSA
test = food["2025-09":]                          # the same 12 test months for both options

def fit_ets(y):                                  # one fixed model for both windows: ETS(A,Ad,A)
    return ETSModel(y, error="add", trend="add", damped_trend=True, seasonal="add", seasonal_periods=12).fit(disp=False)

# Option A: every month since 2015, including the 2020 lockdown collapse
long = food[:"2025-08"]
# Option B: start after the collapse
# blank: the first year of the shorter window, as a string (January of the year after 2020)
short = food["______":"2025-08"]

fit_long, fit_short = fit_ets(long), fit_ets(short)
fc_long = fit_long.forecast(12)                  # forecast the 12 test months
# blank: the horizon, so the forecast covers the whole test period
fc_short = fit_short.forecast(______)

# Compare in dollars on the same months. (Not MASE: its yardstick is computed from each training window.)
# blank: the pandas method that averages, applied to the absolute errors
mae = {"long": (test - fc_long).abs().______(),
       "short": (test - fc_short).abs().mean()}
print({k: int(round(v)) for k, v in mae.items()})     # $ millions per month
alpha = lambda f: dict(zip(f.param_names, f.params))["smoothing_level"]   # pull alpha out of a fit
print({"long": round(float(alpha(fit_long)), 2), "short": round(float(alpha(fit_short)), 2)})   # how jumpy each level is
