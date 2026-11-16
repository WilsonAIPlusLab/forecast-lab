#| **Step 1: choose your series and write the data note.** Change the six settings to any monthly series in the table above. The defaults are **U.S. light vehicle sales** (`TOTALNSA`): thousands of new cars and light trucks sold each month, **not seasonally adjusted**. `scale` converts FRED's units into the units you will report (1,000 turns $ millions into $ billions; use 1 to keep them). Everything below adapts to your choice.
import warnings; warnings.filterwarnings("ignore")   # hide optimizer warnings
from statsmodels.tsa.holtwinters import ExponentialSmoothing   # Holt-Winters / exponential smoothing
from statsmodels.tsa.seasonal import seasonal_decompose         # classical decomposition (Chapter 2)
id     = "TOTALNSA"                           # FRED ID of your series
name   = "U.S. light vehicle sales"           # what to call it in the summary
adj    = "not seasonally adjusted"            # copy SA or NSA from the data catalog
scale  = 1                                    # FRED units / scale = units you report
units  = "thousand vehicles"                  # report units in words ("billion dollars", "percent", ...)
digits = 0                                    # decimals to show (2 for rates and for payrolls in millions)
y = fred(id, start=2010) / scale              # monthly data from January 2010, in report units
y.index.freq = "MS"                           # tell pandas the data are monthly (month-start dates)
num = lambda v: f"{v:,.{digits}f}"            # e.g. 1,234.5
print(f"Data note: {name} (FRED {id}), {units}, {adj}, monthly, {y.index[0]:%b %Y} to {y.index[-1]:%b %Y}, {len(y)} months.")

#| **Step 2: plot it and check your label.** Look for trend, seasonality, outliers (2020!) and breaks before any model. Then check the SA/NSA label against the data with the multiplicative decomposition from [Chapter 2](/chapters/decomposition/), run on 2010 to 2019 so the 2020 shock cannot distort it: the seasonal factors say how far each month typically runs above or below the trend (1.10 = 10% above). A big gap between the highest and lowest month means strong seasonality, which you should see only in **NSA** data. In SA data the gap is close to zero.
viz_ts(y, ylab=units, title=f"{name} since 2010 ({adj})")   # look before you model
pre2020 = y[:"2019-12"]                       # 2010-2019 only: 2020 would distort the factors
sf = seasonal_decompose(pre2020, model="multiplicative").seasonal.iloc[:12]   # the 12 seasonal factors, Jan to Dec
sf.index = sf.index.strftime("%b")            # label them by month name (the sample starts in January)
sf.index.name, sf.name = None, "% gap from trend"   # tidy labels for printing
print((100 * (sf - 1)).round(1))              # each month's typical % gap from the trend
print(f"Seasonal swing: {pd.to_datetime(sf.idxmax(), format='%b'):%B} is typically {100 * (sf.max() - 1):.0f}% above trend, "
      f"{pd.to_datetime(sf.idxmin(), format='%b'):%B} {100 * (1 - sf.min()):.0f}% below.")

#| **Step 3: benchmark first, then one model, on an honest test.** At 8 forecast origins (one every 6 months over the last four years) every method is re-fitted on the data up to that origin and forecasts the next 12 months. The exponential smoothing form (trend, seasonality) is chosen once by AICc, on data **before the first origin**, so the test never peeks ahead. The scorecard reports MAE in your units and the bias (positive = forecasts too low).
h, n = 12, len(y)                             # forecast 1 to 12 months ahead; n = number of months
origins = list(range(n - 48, n - 5, 6))       # 8 origins over the last four years
forms = [dict(trend=None, seasonal=None),                               # level only
         dict(trend="add", damped_trend=True, seasonal=None),           # + damped trend
         dict(trend="add", damped_trend=True, seasonal="add"),          # + fixed-size seasonal swings
         dict(trend="add", damped_trend=True, seasonal="mul")]          # + swings that scale with the level
# fit every candidate form on early data only (** unpacks the settings), keep the lowest AICc
form = min(forms, key=lambda f: ExponentialSmoothing(y.iloc[:origins[0]], seasonal_periods=12, **f).fit().aicc)
def ets(x):                                   # the chosen form, re-estimated on x
    return ExponentialSmoothing(x, seasonal_periods=12, **form).fit().forecast(h).values
methods = {"Seasonal naive": lambda x: np.tile(x.values[-12:], 2)[:h],              # same month last year
           "Naive": lambda x: np.repeat(x.values[-1], h),                            # last value carried forward
           "Drift": lambda x: x.values[-1] + (x.values[-1] - x.values[0]) / (len(x) - 1) * np.arange(1, h + 1),  # straight line
           "ETS": ets}
errs = {}                                     # one table per method: rows = origins, columns = horizons
for m, fun in methods.items():
    E = np.full((len(origins), h), np.nan)    # NaN where the actual is not known yet
    for r, o in enumerate(origins):
        f = fun(y.iloc[:o])                   # fit on the first o months only
        k = min(h, n - o)                     # horizons whose actual value we have
        E[r, :k] = y.values[o:o + k] - f[:k]  # error = actual minus forecast
    errs[m] = E
score = pd.DataFrame({"MAE": {m: np.nanmean(np.abs(E)) for m, E in errs.items()},            # typical miss, all horizons
                      "MAE 1 month": {m: np.mean(np.abs(E[:, 0])) for m, E in errs.items()},  # typical miss, 1 month ahead
                      "Bias": {m: np.nanmean(E) for m, E in errs.items()}})                   # mean error
best = score["MAE"].idxmin()                  # the method with the lowest MAE
viz_table(score, highlight=["MAE", "MAE 1 month"], digits=2,
          title=f"{best} wins the honest test ({units}; ETS trend {form['trend']}, seasonal {form['seasonal']})")

#| **Step 4: the forecast and an 80% range you can defend.** The best method is re-fitted on all the data. Its 80% range for 12 months ahead adds the 10th and 90th percentiles of the errors it made 12 months ahead at past origins (only 8 errors, so the edges are rough). Then the forecast is compared **like with like**: with the same month a year earlier, which is safe for SA and NSA data alike.
fc = methods[best](y)                         # final forecasts from all the data
point = fc[h - 1]                             # the forecast 12 months out (Python counts from 0)
q = np.nanquantile(errs[best][:, h - 1], [0.10, 0.90])   # past 12-month-ahead errors
lo80, hi80 = point + q[0], point + q[1]       # forecast + 10th / 90th-percentile error
same_month = y.iloc[-12:].values[h - 1]       # actual value 12 months before the target month
rate = "percent" in units                     # rates are compared in percentage points, not percent
miss_units = "percentage points" if rate else units   # a miss in a rate is measured in points
yoy = point - same_month if rate else 100 * (point / same_month - 1)   # change on the same month a year earlier
when = f"{y.index[-1] + pd.DateOffset(months=h):%B %Y}"   # target month in words
if point < lo80 or point > hi80:              # past errors all on one side: say so as the key risk
    print("Note: the forecast lies outside its own 80% range, because this method's past errors were almost all on one side (bias). Make that the key risk.")

#| **Step 5: the executive summary.** Bottom line first: a number with units and a date, a like-with-like comparison, a range, and a track record against the benchmark in your reader's units. Add the key risk and the trigger yourself, in your own words: they need judgement that code cannot supply.
vs_bench = 100 * (1 - score.loc[best, "MAE"] / score.loc["Seasonal naive", "MAE"])   # % smaller miss than seasonal naive
if best == "Seasonal naive":                  # the benchmark won: say so plainly
    track = (f"no method beat the simple rule of using the same month last year, whose typical miss was "
             f"{num(score.loc[best, 'MAE 1 month'])} {miss_units} one month ahead")
else:                                         # a method won: compare it with the benchmark
    track = (f"the most accurate method was {best}: its typical miss was {num(score.loc[best, 'MAE 1 month'])} {miss_units} "
             f"one month ahead, and its average miss was {abs(vs_bench):.0f}% {'smaller' if vs_bench >= 0 else 'larger'} "
             "than using the same month last year")
change = f"{abs(yoy):.2f} percentage points" if rate else f"{abs(yoy):.1f}%"   # the comparison, in the right units
summary_text = (f"We expect {name} ({adj}) to be about {num(point)} {units} in {when}, {change} "
                f"{'above' if yoy >= 0 else 'below'} the same month a year earlier. Our 80% range is {num(lo80)} to {num(hi80)} {units}. "
                f"Over 8 forecast origins in the past four years, {track}.")
print(summary_text)
