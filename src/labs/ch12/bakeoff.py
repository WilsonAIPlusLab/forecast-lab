#| **Start from the feature table of Lab 13.1.** A hidden setup step rebuilt it: `d` holds every month, `train` is 1993–2022, `test` is January 2023 onward. Each test row uses only information published by the middle of that month, so every test forecast is a genuine **one-month-ahead** forecast.
print({"train_months": len(train), "test_months": len(test)})   # rows in each block
def X(df):                                    # helper: rows -> XGBoost's data format
    return xgb.DMatrix(df[features], label=df["growth"])

#| **Tune on rolling folds, never on the test set.** Each fold starts one year (2019 to 2022), trains on everything before it and scores that year. We try four combinations of learning rate (0.1, 0.3) and depth (2, 3), the same grid as the R lab. Early stopping picks the number of trees inside each fold (patience: 20 rounds).
folds = [(X(d[: f"{yr - 1}-12"]), X(d.loc[str(yr)])) for yr in range(2019, 2023)]   # (train, validate) per year
rows = []                                     # one result row per grid combination
for eta in [0.1, 0.3]:                        # learning rates
    for depth in [2, 3]:                      # tree depths
        p = {"eta": eta, "max_depth": depth, "tree_method": "exact", "nthread": 1}
        rmse, rounds = [], []
        for a, b in folds:
            m = xgb.train(p, a, num_boost_round=500, evals=[(b, "valid")], early_stopping_rounds=20, verbose_eval=False)
            rmse.append(m.best_score); rounds.append(m.best_iteration + 1)   # best validation RMSE; trees (count from 1)
        rows.append({"eta": eta, "max_depth": depth, "cv_rmse": np.mean(rmse), "rounds": round(np.mean(rounds))})   # average over folds
grid = pd.DataFrame(rows).sort_values("cv_rmse")   # best settings first
print(grid.round(4))

#| **Refit the winner on 1993–2022 and forecast the test months**, converting predicted growth back to dollars.
best = grid.iloc[0]                           # first row = lowest CV error
fit = xgb.train({"eta": best["eta"], "max_depth": int(best["max_depth"]), "tree_method": "exact", "nthread": 1},
                X(train), num_boost_round=int(best["rounds"]))
f_xgb = test["lag1"] * (1 + fit.predict(X(test)) / 100)   # dollars = last month x (1 + growth / 100)

#| **Three rivals on the same months:** a random forest on the same features, ETS(M,A,M) fitted through 2022 and run forward without re-estimating, and seasonal naive. scikit-learn's forest is not identical to R's `randomForest`, and statsmodels estimates slightly different ETS parameters than R's `forecast`, so those two rows differ a little from the R lab. XGBoost matches R exactly.
from sklearn.ensemble import RandomForestRegressor
from statsmodels.tsa.exponential_smoothing.ets import ETSModel
rf = RandomForestRegressor(n_estimators=300, max_features=2, min_samples_leaf=3, random_state=12)   # random_state = seed
rf.fit(train[features], train["growth"])
f_rf = test["lag1"] * (1 + rf.predict(test[features].ffill()) / 100)   # .ffill() fills the one gap with the month before
spec = dict(error="mul", trend="add", seasonal="mul", seasonal_periods=12)   # ETS(M,A,M)
ets_fit = ETSModel(retail[:"2022-12"], **spec).fit(disp=False)   # estimate on data through 2022 (** unpacks spec)
f_ets = ETSModel(retail, **spec).smooth(ets_fit.params).fittedvalues["2023-01":]   # same parameters on all data: 1-step forecasts
f_snaive = retail.shift(12)["2023-01":]       # seasonal naive: same month last year

#| **Add a combination**: the average of XGBoost and ETS.
f_combo = (f_xgb + f_ets) / 2                 # 50/50 forecast combination
# helper: error metrics for a forecast f; e = errors in $ billions
def score(f):
    e = (test["sales"] - f) / 1000
    return {"ME ($bn)": e.mean(), "MAE ($bn)": e.abs().mean(), "RMSE ($bn)": np.sqrt((e**2).mean()),
            "MAPE (%)": 100 * (e * 1000 / test["sales"]).abs().mean()}
scores = pd.DataFrame({"XGBoost": score(f_xgb), "Random forest": score(f_rf), "ETS": score(f_ets),
                       "XGBoost + ETS average": score(f_combo), "Seasonal naive": score(f_snaive)}).T   # .T = one row per method
print(scores.round(2))

#| **The scorecard.** On one long, well-behaved series, tuned boosting does **not** beat ETS. Averaging the two gives the lowest RMSE.
viz_table(scores, highlight=["MAE ($bn)", "RMSE ($bn)", "MAPE (%)"], digits=2,   # green = best in each column
          title="On one series, boosting does not beat ETS; averaging the two avoids the big misses")
viz_compare(history=retail["2020":"2022"], actual=retail["2023":], XGBoost=f_xgb, ETS=f_ets,
            title="Both models track the December peaks one month ahead")
