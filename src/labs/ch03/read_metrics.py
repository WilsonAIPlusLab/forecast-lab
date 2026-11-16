#| **Re-create the seasonal naive forecast from the scorecard.** Same data and same split as before: train through December 2022, test from January 2023. The errors `err` are **actual minus forecast**, in millions of dollars. A positive error means the forecast was too low.
retail = fred("RSXFSN", start=2010)           # monthly U.S. retail sales, $ millions, not seasonally adjusted
train = retail[:"2022-12"]                    # training set: through December 2022
test = retail["2023-01":]                     # test set: January 2023 onward
# seasonal naive: repeat the last 12 training months (i % 12 cycles 0..11)
f = pd.Series([train.iloc[-12 + (i % 12)] for i in range(len(test))], index=test.index)
err = test - f                                # forecast errors: actual minus forecast ($ millions)

#| **Bias: which way do we miss?** The mean error (ME) is about +22,000, so on average the forecast is **too low** by about \$22 billion a month. The share of months with a positive error says the same thing in plain words: the forecast was too low in about 4 months out of 5. Why? Nominal retail sales grow every year (more people, higher prices), so "same month last year" lags behind.
print(err.mean())                             # ME (bias): + means forecast too low on average
print((err > 0).mean())                       # share of months where the forecast was too low
print(err.mean() / err.abs().mean())          # ME / MAE near +1 or -1: almost every miss goes the same way

#| **Typical miss vs big misses.** MAE is the size of a typical miss in the data's units. RMSE squares the errors first, so it is always at least as large as MAE. The ratio RMSE ÷ MAE is about 1.26 here: the misses are uneven, and the biggest ones come at the end of the test period. `.idxmax()` finds the worst month: the last one, September 2026, because seasonal naive keeps repeating 2022's values while sales keep growing, so it falls further behind every year.
mae = err.abs().mean()                        # MAE: average size of a miss, $ millions
rmse = np.sqrt((err**2).mean())               # RMSE: root of the average squared miss, $ millions
print({"MAE": round(mae), "RMSE": round(rmse), "ratio": round(float(rmse / mae), 4)})   # ratio 1 = all misses equal
print(err.abs().idxmax().date())              # date of the largest miss (.idxmax() returns its index label)
print(err.abs().max())                        # size of that largest miss, $ millions

#| **Plot the errors over time.** A line hugging zero would mean no bias. Here most errors sit above zero: the picture of a forecast that is systematically too low.
years = test.index.year + test.index.month / 12 - 1 / 12   # date as a decimal year, like R's time()
viz_lines(years, Error=err.values, zero=True, xlab="year",   # zero line for reference
          ylab="actual − forecast ($ millions)", title="Seasonal naive misses low in most months")

#| **When MAPE misleads: interest rates near zero.** Forecast the federal funds rate one month ahead with the naive rule (next month = this month). In 2004–07 the rate was between 1% and 5.3%; in 2010–15 it sat near 0.1%. The misses in 2010–15 were about **nine times smaller** in percentage points, yet MAPE is **more than twice as large**, because each tiny miss is divided by a tiny actual value.
ff = fred("FEDFUNDS", start=2003)             # effective federal funds rate, %, monthly
eff = (ff - ff.shift(1)).dropna()             # naive one-month-ahead errors: this month minus last month
yff = ff.loc[eff.index]                       # the actual values those errors are compared with
def era(a, b):                                # MAE and MAPE for the months from year a through year b
    k = (eff.index.year >= a) & (eff.index.year <= b)   # True for months inside the era
    return {"MAE (pct. points)": eff[k].abs().mean(), "MAPE (%)": 100 * (eff[k] / yff[k]).abs().mean()}
tab = pd.DataFrame({"2004-07 (rate 1-5%)": era(2004, 2007),
                    "2010-15 (rate near 0.1%)": era(2010, 2015)}).T   # .T: one row per era
print(tab.round(3))

#| **Show it as a table.** Same forecasting rule, much smaller misses, but a worse MAPE. That is why MAPE is a poor choice for series near zero, and meaningless for series that can be negative.
viz_table(tab, digits=3, title="Near zero, tiny misses produce a big MAPE")
