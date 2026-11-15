#| **Load the target and two macro drivers.** `RSXFSN` is U.S. retail sales excluding food services, **not seasonally adjusted**, in $ millions per month. Consumer sentiment and the unemployment rate are the macro drivers. We read those two raw files directly: the unemployment rate has a real hole (October 2025 was never published because of the federal shutdown). `fred()` would fill it by interpolation, which uses *November's* value, information nobody had when forecasting November. That is a small leak, so we keep the hole.
import xgboost as xgb
retail = fred("RSXFSN", start=1992)
raw = lambda id: pd.read_csv(f"data/{id}.csv", index_col=0, parse_dates=True, na_values=[".", ""]).iloc[:, 0]
sent, unemp = raw("UMCSENT"), raw("UNRATE")

#| **Predict growth, not levels.** Trees can only predict values they have seen in training, so we predict this month's **growth over last month, in %** and turn it back into dollars with *forecast = last month × (1 + growth/100)*.
d = pd.DataFrame({"sales": retail})
d["lag1"] = d["sales"].shift(1)
d["growth"] = 100 * (d["sales"] / d["lag1"] - 1)

#| **Build the features.** Every feature must be known when the forecast is made (once last month's sales are published, about two weeks into the month): calendar month, same-month-last-year growth, last month's growth, last month's 12-month growth, weekend days in the month, and last month's sentiment and unemployment rate.
d["month"] = d.index.month
d["growth_ly"] = d["growth"].shift(12)
d["growth_lm"] = d["growth"].shift(1)
d["yoy_lm"] = 100 * (d["lag1"] / d["sales"].shift(13) - 1)
d["weekend"] = [int((pd.date_range(t, t + pd.offsets.MonthEnd(0)).dayofweek >= 5).sum()) for t in d.index]
d["sent_lm"] = sent.reindex(pd.date_range("1950-01-01", d.index[-1], freq="MS")).shift(1).reindex(d.index)
d["unrate_lm"] = unemp.reindex(pd.date_range("1948-01-01", d.index[-1], freq="MS")).shift(1).reindex(d.index)
d = d.dropna(subset=["growth_ly", "yoy_lm"])
features = ["month", "growth_ly", "growth_lm", "yoy_lm", "weekend", "sent_lm", "unrate_lm"]
print(d[["growth"] + features].tail(3).round(2))

#| **Split by time into three blocks:** fit on 1993–2021, validate on 2022, and keep 2023 onward untouched for Lab 12.2. `xgb.DMatrix` packs features and label; missing values are allowed.
fit_d, valid_d = d[:"2021-12"], d["2022-01":"2022-12"]
dfit = xgb.DMatrix(fit_d[features], label=fit_d["growth"])
dvalid = xgb.DMatrix(valid_d[features], label=valid_d["growth"])

#| **Train with early stopping.** `eta` is the learning rate, `max_depth` the tree depth, `subsample` the share of rows per tree, and `tree_method="exact"` tries every split, so R and Python give identical answers. Training stops once validation error has not improved for 50 rounds.
params = {"objective": "reg:squarederror", "eta": 0.05, "max_depth": 3, "subsample": 1, "tree_method": "exact", "nthread": 1}
log = {}
boost = xgb.train(params, dfit, num_boost_round=1000, evals=[(dfit, "train"), (dvalid, "valid")],
                  early_stopping_rounds=50, evals_result=log, verbose_eval=False)

#| **Read the learning curve.** Training error keeps falling; validation error bottoms out and drifts up. `best_iteration` counts from 0, so we add 1.
best = boost.best_iteration + 1
rounds = np.arange(1, len(log["train"]["rmse"]) + 1)
viz_lines(rounds, Training=log["train"]["rmse"], Validation=log["valid"]["rmse"], xlab="Boosting round (number of trees)",
          ylab="RMSE, % points of monthly growth", title=f"Validation error bottoms out after {best} trees",
          subtitle="Fit on 1993-2021, validated on 2022. Training error keeps falling; validation error does not.")
print({"best_round": best, "valid_rmse": round(log["valid"]["rmse"][best - 1], 4)})

#| **Refit on 1993–2022 with exactly that many trees**, then look at gain importance.
train = d[:"2022-12"]
fit = xgb.train(params, xgb.DMatrix(train[features], label=train["growth"]), num_boost_round=best)
gain = pd.Series(fit.get_score(importance_type="total_gain"))
viz_bars(gain / gain.sum(), title="Two seasonal features do most of the work",
         subtitle="Gain importance: share of the total loss reduction from splits on each feature")
