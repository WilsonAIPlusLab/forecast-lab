#| **Refit the tuned model from Lab 12.2** (learning rate 0.1, depth-2 trees, 38 rounds). The hidden setup rebuilt `train` (1993–2022) and `test` (2023 onward).
params = {"eta": 0.1, "max_depth": 2, "tree_method": "exact", "nthread": 1}   # the tuned settings
fit = xgb.train(params, xgb.DMatrix(train[features], label=train["growth"]), num_boost_round=38)   # 38 trees
dtest = xgb.DMatrix(test[features])           # test features only
pred = fit.predict(dtest)                     # predicted growth, % over last month

#| **Ask for SHAP values** with `pred_contribs=True`. You get one column per feature plus a last column, the **base value** (the model's average prediction). XGBoost computes these exactly with the TreeSHAP algorithm, so you do not need the `shap` package.
S = pd.DataFrame(fit.predict(dtest, pred_contribs=True), index=test.index, columns=features + ["base"])   # months x (7 features + base)
print(S.tail(3).round(2))                     # the last 3 test months

#| **Check additivity**: base value + contributions = prediction, for every month.
print("Additive:", np.allclose(S.sum(axis=1), pred, atol=1e-5))   # sum(axis=1) adds across each row

#| **Translate into dollars**: a contribution of *c* points of growth is worth *last month × c/100*. Divide by 1,000 for billions.
usd = S.mul(test["lag1"] / 100 / 1000, axis=0)   # multiply each row by its own month's factor; $ billions
print(usd.loc["2025-12-01"].round(1))         # .loc picks the December 2025 row by its date label

#| **Draw the waterfall for December 2025**, from November's sales to the forecast. `viz_custom("waterfall", ...)` is a chart type this chapter adds to the site.
# readable labels for the chart, keyed by column name
nice = {"month": "Calendar month", "growth_ly": "Same month last year's growth", "growth_lm": "Last month's growth",
        "yoy_lm": "Last month's 12-month growth", "weekend": "Weekend days", "sent_lm": "Consumer sentiment (last month)",
        "unrate_lm": "Unemployment rate (last month)"}
# helper: waterfall chart for one month (row), from its dollar SHAP values and predicted growth
def waterfall(row, contrib_usd, growth_pred, title):
    v = contrib_usd[features]; o = v.abs().sort_values(ascending=False).index   # feature names, biggest push first
    fc = row["lag1"] * (1 + growth_pred / 100) / 1000   # the forecast, $ billions
    actual = "not yet known" if pd.isna(row["sales"]) else f"${row['sales'] / 1000:.1f}bn"
    viz_custom("waterfall", title=title, unit="$bn",
               subtitle=f"Starts from last month's sales (${row['lag1'] / 1000:.1f}bn) and ends at the forecast (${fc:.1f}bn). Actual: {actual}.",
               start=row["lag1"] / 1000, start_label="Last month's sales", base=float(contrib_usd["base"]),   # first bars
               labels=[nice[f] for f in o], values=[float(v[f]) for f in o],   # one bar per feature, in order o
               feature_values=[None if pd.isna(row[f]) else float(row[f]) for f in o], total_label="Forecast")
i = test.index.get_loc(pd.Timestamp("2025-12-01"))   # row position of December 2025
waterfall(test.iloc[i], usd.iloc[i], pred[i], "December 2025: last year's December jump does most of the lifting")

#| **Global importance**: the average absolute SHAP value per feature over the 45 test months, in dollars.
imp = usd[features].abs().mean().rename(nice)   # mean |SHAP| per feature, $ billions, with readable labels
viz_bars(imp, xlab="Mean |SHAP|, $ billions", title="Seasonal features move the forecast most; macro drivers barely register",
         subtitle="Average absolute SHAP value per feature, one-month-ahead forecasts, Jan 2023 to Sep 2026")

#| **Next month's forecast, explained.** Refit on everything through September 2026 and explain October 2026.
full = d.dropna(subset=["growth"])            # every month with a known target
fit_all = xgb.train(params, xgb.DMatrix(full[features], label=full["growth"]), num_boost_round=38)   # same settings, all data
nxt = make_features(retail, extra_month=True).iloc[[-1]]   # the one row for next month ([[-1]] keeps it a table)
dnext = xgb.DMatrix(nxt[features])
# SHAP values for that row, converted to $ billions
contrib = pd.Series(fit_all.predict(dnext, pred_contribs=True)[0], index=features + ["base"]) * nxt["lag1"].iloc[0] / 100 / 1000
waterfall(nxt.iloc[0], contrib, fit_all.predict(dnext)[0], "October 2026: the forecast, and why")
