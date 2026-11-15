#| **Rebuild the feature table** (retail sales growth, % per month, NSA) and split it by time. scikit-learn needs numbers, so `month` is the integer 1–12 here (R treats it as a category; see the note at the end).
from sklearn.tree import DecisionTreeRegressor
retail = fred("RSXFSN", start=2010)
g = (100 * np.log(retail).diff()).dropna()
feats = pd.DataFrame({"g": g, "g1": g.shift(1), "g2": g.shift(2), "g12": g.shift(12), "month": g.index.month})
train = feats[:"2022-12"].dropna()
test = feats["2023-01":]
X_cols = ["g1", "g2", "g12", "month"]

#| **Grow a regression tree** of depth 3. At every node it tries every feature and cut point and keeps the split that most reduces the sum of squared errors.
fit = DecisionTreeRegressor(max_depth=3, min_samples_leaf=5, random_state=0).fit(train[X_cols], train["g"])
from sklearn.tree import export_text
print(export_text(fit, feature_names=X_cols, decimals=2))

#| **Draw it.** We walk the fitted tree and send its nodes to the same chart the R version uses. Leaf values are the average training growth of the months that land there.
t = fit.tree_
nodes = []
def walk(i, nid, label):
    leaf = t.children_left[i] == -1
    nodes.append({"id": nid, "var": "<leaf>" if leaf else X_cols[t.feature[i]], "n": int(t.n_node_samples[i]),
                  "yval": round(float(t.value[i][0][0]), 2), "label": label})
    if not leaf:
        f, thr = X_cols[t.feature[i]], t.threshold[i]
        walk(t.children_left[i], 2 * nid, f"{f} <= {thr:.3g}")
        walk(t.children_right[i], 2 * nid + 1, f"{f} > {thr:.3g}")
walk(0, 1, "root")
viz_custom("ch11-tree", title="Three questions sort every month into a handful of forecasts",
           subtitle="Regression tree for monthly retail sales growth (%), trained 2011–2022", nodes=nodes)

#| **Predictions are piecewise constant**: every forecast is one of the leaf averages.
print(np.unique(fit.predict(test[X_cols]).round(2)))

#| **Depth vs error.** Training error keeps falling; test error stops improving early.
rmse = lambda a, f: float(np.sqrt(np.mean((a - f) ** 2)))
depths = range(1, 11)
err = pd.DataFrame([{"train": rmse(train["g"], m.predict(train[X_cols])), "test": rmse(test["g"], m.predict(test[X_cols]))}
                    for m in (DecisionTreeRegressor(max_depth=d, min_samples_leaf=2, random_state=0).fit(train[X_cols], train["g"]) for d in depths)],
                   index=depths)
print(err.round(2).T)
viz_lines(list(depths), Training=err["train"], Test=err["test"], xlab="tree depth",
          ylab="RMSE (pp of monthly growth)", zero=True, title="Deeper trees fit the past better, not the future")
# Note: with an integer month, sklearn can only cut months into ranges (e.g. month > 11.5),
# while R's rpart can group any set of months, so the two trees differ in detail.
