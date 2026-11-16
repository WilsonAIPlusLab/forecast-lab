#| **A steadily trending series**: U.S. e-commerce sales (MRTSSM4541USS, $ millions, seasonally adjusted). Train through December 2022 and note the training maximum.
from sklearn.ensemble import RandomForestRegressor
ecom = fred("MRTSSM4541USS", start=2010)      # monthly e-commerce sales, $ millions, seasonally adjusted
train, test = ecom[:"2022-12"], ecom["2023-01":]   # train through Dec 2022, test from Jan 2023
h = len(test)                                 # forecast horizon = number of test months
print(train.max())                            # the highest month the models will ever see

#| **A lag table and a recursive forecaster.** Forecast one month, append it to the history as if it were data, repeat.
def lag_table(x):
    x = np.asarray(x, dtype=float)
    # row t: target x[t] and the three values before it (x[3:] = from the 4th value on)
    return pd.DataFrame({"y": x[3:], "lag1": x[2:-1], "lag2": x[1:-2], "lag3": x[:-3]})

def recursive(model, history, h):
    hist = list(np.asarray(history, dtype=float))
    for _ in range(h):                        # one pass per month ahead
        new = pd.DataFrame({"lag1": [hist[-1]], "lag2": [hist[-2]], "lag3": [hist[-3]]})   # last 3 values
        hist.append(float(model.predict(new)[0]))   # append the forecast as if it were data
    return np.array(hist[-h:])                # return only the h forecasts

#| **Forest 1: forecast the level.** 200 trees; each split looks at one randomly chosen lag, like R's default for 3 features.
cols = ["lag1", "lag2", "lag3"]               # the feature columns
tab = lag_table(train)
rf_level = RandomForestRegressor(n_estimators=200, max_features=1, min_samples_leaf=5, random_state=11).fit(tab[cols], tab["y"])
fc_level = recursive(rf_level, train, h)      # forecast dollar levels for every test month
print(fc_level.min().round(), fc_level.max().round())   # lowest and highest forecast

#| **The trap, in numbers.** No forecast can exceed the largest training target.
print({"training_max": float(train.max()), "highest_forecast": round(float(fc_level.max())), "highest_actual": float(test.max())})

#| **Forest 2: forecast the growth rate**, then compound back to dollars from the last observed level.
gr = (100 * np.log(train).diff()).dropna()    # monthly growth, %
tab_g = lag_table(gr)
rf_growth = RandomForestRegressor(n_estimators=200, max_features=1, min_samples_leaf=5, random_state=11).fit(tab_g[cols], tab_g["y"])
fc_growth = train.iloc[-1] * np.exp(np.cumsum(recursive(rf_growth, gr, h)) / 100)   # compound from the last level

#| **Compare both against what happened.**
viz_compare(history=train["2018":], actual=test,
            # ** unpacks a dict into named arguments; pd.Series gives the forecasts test-set dates
            **{"Forest on levels": pd.Series(fc_level, index=test.index), "Forest on growth": pd.Series(fc_growth, index=test.index)},
            title="A forest trained on levels cannot forecast above its training maximum")
print({"levels": round(float(np.mean(np.abs(test - fc_level)))), "growth": round(float(np.mean(np.abs(test - fc_growth))))})   # MAE, $ millions

#| **Two more ways out: differences and detrending.** *Differences*: forecast the dollar change, then add the changes up from the last level. *Detrending*: fit a straight line to log sales, let the forest forecast the gap from that line, then add the line back and undo the log with `np.exp()`.
dd = train.diff().dropna()                    # monthly change, $ millions
tab_d = lag_table(dd)
rf_diff = RandomForestRegressor(n_estimators=200, max_features=1, min_samples_leaf=5, random_state=11).fit(tab_d[cols], tab_d["y"])
fc_diff = train.iloc[-1] + np.cumsum(recursive(rf_diff, dd, h))   # last level + running total of changes
tt = np.arange(1, len(train) + 1)             # time index 1, 2, ..., n
b, a = np.polyfit(tt, np.log(train.values), 1)   # log-linear trend: log sales = a + b * t (slope first)
gap = np.log(train.values) - (a + b * tt)     # how far each month sits above (+) or below (-) the trend line
tab_r = lag_table(gap)
rf_gap = RandomForestRegressor(n_estimators=200, max_features=1, min_samples_leaf=5, random_state=11).fit(tab_r[cols], tab_r["y"])
line_ahead = a + b * (len(train) + np.arange(1, h + 1))   # the trend line extended h months
fc_detr = np.exp(line_ahead + recursive(rf_gap, gap, h))  # trend + forecast gap, back from logs to dollars
mae = lambda f: round(float(np.mean(np.abs(test.values - f))))   # mean absolute error, $ millions
print({"levels": mae(fc_level), "growth": mae(fc_growth), "differences": mae(fc_diff), "detrended": mae(fc_detr)})
