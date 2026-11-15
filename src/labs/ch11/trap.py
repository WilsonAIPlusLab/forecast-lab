#| **A steadily trending series**: U.S. e-commerce sales (MRTSSM4541USS, $ millions, seasonally adjusted). Train through December 2022 and note the training maximum.
from sklearn.ensemble import RandomForestRegressor
ecom = fred("MRTSSM4541USS", start=2010)
train, test = ecom[:"2022-12"], ecom["2023-01":]
h = len(test)
print(train.max())

#| **A lag table and a recursive forecaster.** Forecast one month, append it to the history as if it were data, repeat.
def lag_table(x):
    x = np.asarray(x, dtype=float)
    return pd.DataFrame({"y": x[3:], "lag1": x[2:-1], "lag2": x[1:-2], "lag3": x[:-3]})

def recursive(model, history, h):
    hist = list(np.asarray(history, dtype=float))
    for _ in range(h):
        new = pd.DataFrame({"lag1": [hist[-1]], "lag2": [hist[-2]], "lag3": [hist[-3]]})
        hist.append(float(model.predict(new)[0]))
    return np.array(hist[-h:])

#| **Forest 1: forecast the level.** 200 trees; each split looks at one randomly chosen lag, like R's default for 3 features.
cols = ["lag1", "lag2", "lag3"]
tab = lag_table(train)
rf_level = RandomForestRegressor(n_estimators=200, max_features=1, min_samples_leaf=5, random_state=11).fit(tab[cols], tab["y"])
fc_level = recursive(rf_level, train, h)
print(fc_level.min().round(), fc_level.max().round())

#| **The trap, in numbers.** No forecast can exceed the largest training target.
print({"training_max": float(train.max()), "highest_forecast": round(float(fc_level.max())), "highest_actual": float(test.max())})

#| **Forest 2: forecast the growth rate**, then compound back to dollars from the last observed level.
gr = (100 * np.log(train).diff()).dropna()
tab_g = lag_table(gr)
rf_growth = RandomForestRegressor(n_estimators=200, max_features=1, min_samples_leaf=5, random_state=11).fit(tab_g[cols], tab_g["y"])
fc_growth = train.iloc[-1] * np.exp(np.cumsum(recursive(rf_growth, gr, h)) / 100)

#| **Compare both against what happened.**
viz_compare(history=train["2018":], actual=test,
            **{"Forest on levels": pd.Series(fc_level, index=test.index), "Forest on growth": pd.Series(fc_growth, index=test.index)},
            title="A forest trained on levels cannot forecast above its training maximum")
print({"levels": round(float(np.mean(np.abs(test - fc_level)))), "growth": round(float(np.mean(np.abs(test - fc_growth))))})
