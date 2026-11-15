#| **Stand in December 2019.** Train on retail sales 2010–2019 (`RSXFSN`, $ millions, monthly, **not** seasonally adjusted) and keep 2020–2021 aside as "what really happened". statsmodels has no automatic ETS selection, so we fit the model R's `ets()` picks for these data: multiplicative errors, damped additive trend, multiplicative seasonality, ETS(M,Ad,M).
import warnings; warnings.filterwarnings("ignore")   # hide statsmodels fitting warnings
from statsmodels.tsa.exponential_smoothing.ets import ETSModel   # exponential smoothing (ETS) state-space model
retail = fred("RSXFSN", start=2010)           # monthly U.S. retail sales, $ millions, not seasonally adjusted
train = retail[:"2019-12"]                    # training set: up to December 2019
actual = retail["2020-01":"2021-12"]          # what really happened, 2020-2021 (24 months)
# ETS(M,Ad,M): multiplicative errors, damped additive trend, multiplicative 12-month seasonality
fit = ETSModel(train, error="mul", trend="add", damped_trend=True, seasonal="mul", seasonal_periods=12).fit(disp=False)

#| **Way 1: the model's own intervals.** `get_prediction().summary_frame(alpha)` returns the lower and upper limits. For multiplicative models statsmodels computes them by simulation (there is no exact formula), so they will differ slightly from R's.
np.random.seed(2026)                          # these intervals are simulated too: fix the draws so they repeat
pred = fit.get_prediction(start=len(train), end=len(train) + 23)   # the 24 months after the training data
f80, f95 = pred.summary_frame(alpha=0.20), pred.summary_frame(alpha=0.05)   # alpha = 1 - level: 80% and 95%
viz_forecast(train["2016":], f80["mean"], lower=[f80["pi_lower"], f95["pi_lower"]], upper=[f80["pi_upper"], f95["pi_upper"]],
             levels=("80%", "95%"), actual=actual, method="ETS(M,Ad,M)",   # overlay the real 2020-21 data
             title="The 95% fan from December 2019 missed the pandemic")

#| **Way 2: bootstrapped residuals.** `random_errors="bootstrap"` re-uses the model's own past errors, drawn with replacement, instead of assuming normal shocks.
np.random.seed(2026)                          # fix the random draws so results repeat exactly
# 2,000 paths starting after Dec 2019
boot = fit.simulate(24, repetitions=2000, anchor="end", random_errors="bootstrap")
# 10th/90th percentile per month = 80% interval
b_lo, b_hi = boot.quantile(0.10, axis=1), boot.quantile(0.90, axis=1)

#| **Way 3: simulate whole future paths.** Each column of `paths` is one plausible 24-month future. The spread of the spaghetti is the uncertainty.
paths = fit.simulate(24, repetitions=50, anchor="end")   # 50 simulated futures, one per column
hist = train["2017":]                         # history to draw, from 2017
viz_custom("ch10-paths", title="50 futures the model thought possible in December 2019",
           subtitle="Each grey line is one simulated path; gold is what actually happened",
           # dates as "YYYY-MM-DD" text
           hist_date=[d.strftime("%Y-%m-%d") for d in hist.index], hist=hist.tolist(),
           # .T: one row per path
           dates=[d.strftime("%Y-%m-%d") for d in paths.index], paths=paths.T.values.tolist(),
           actual_date=[d.strftime("%Y-%m-%d") for d in actual.index], actual=actual.tolist(), ylab="$ millions")

#| **From paths to an interval.** With 2,000 normal-error paths, the 10th and 90th percentiles at each month form an 80% interval.
many = fit.simulate(24, repetitions=2000, anchor="end")   # 2,000 paths with normal errors
s_lo, s_hi = many.quantile(0.10, axis=1), many.quantile(0.90, axis=1)   # 10th/90th percentile per month

#| **Compare the three.** Similar widths, and the same blind spot: very few of the 24 actual months land inside.
# count months inside
inside = lambda lo, hi: int(((actual.values >= lo.values) & (actual.values <= hi.values)).sum())
# one row per method; .iloc[0] = first month (Jan 2020), .iloc[-1] = last month (Dec 2021)
cmp = pd.DataFrame({
    "Width Jan 2020": [f80["pi_upper"].iloc[0] - f80["pi_lower"].iloc[0], b_hi.iloc[0] - b_lo.iloc[0], s_hi.iloc[0] - s_lo.iloc[0]],
    "Width Dec 2021": [f80["pi_upper"].iloc[-1] - f80["pi_lower"].iloc[-1], b_hi.iloc[-1] - b_lo.iloc[-1], s_hi.iloc[-1] - s_lo.iloc[-1]],
    "Months inside (of 24)": [inside(f80["pi_lower"], f80["pi_upper"]), inside(b_lo, b_hi), inside(s_lo, s_hi)]},
    index=["Model intervals", "Bootstrap", "Simulated paths"])
print(cmp.round(0))                           # widths in $ millions; an honest 80% interval holds about 19 of 24
viz_table(cmp, digits=0, title="Three ways to build an 80% interval, one shared blind spot")
