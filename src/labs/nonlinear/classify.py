#| **Score the clients the model has never seen.** Fit on the training clients (hidden setup: same data and split as before), then predict a probability for each of the 1,237 test clients: the next campaign's call list.
logit = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m", train).fit(disp=0)
p = logit.predict(test).to_numpy()
y = test["yes"].to_numpy()
print(pd.Series(p).describe().round(4))

#| **Confusion matrix at 0.5.** `pd.crosstab` counts predictions against outcomes. Very few clients reach 50%, so the model rarely says yes.
pred50 = (p > 0.5).astype(int)
print(pd.crosstab(pd.Series(pred50, name="predicted"), pd.Series(y, name="actual")))

#| **Five metrics from one table**, written out so every formula is visible.
def metrics(pred, y):
    TP = int(((pred == 1) & (y == 1)).sum()); FP = int(((pred == 1) & (y == 0)).sum())
    FN = int(((pred == 0) & (y == 1)).sum()); TN = int(((pred == 0) & (y == 0)).sum())
    precision = TP / (TP + FP) if TP + FP > 0 else np.nan
    recall = TP / (TP + FN)
    return dict(TP=TP, FP=FP, FN=FN, TN=TN, accuracy=(TP + TN) / len(y), precision=precision, recall=recall,
                specificity=TN / (TN + FP), F1=2 * precision * recall / (precision + recall) if TP > 0 else np.nan)

#| **The accuracy paradox.** Always-no is 89% accurate and finds nobody. The 0.10 threshold is the break-even point if a call costs \$5 and a deposit is worth \$50 (illustrative numbers); `profit` applies them.
rules = {"Logit, threshold 0.5": pred50, "Logit, threshold 0.10": (p > 0.10).astype(int),
         "Call everyone": np.ones_like(y), "Always say no": np.zeros_like(y)}
scores = pd.DataFrame({k: metrics(v, y) for k, v in rules.items()}).T
scores["profit"] = 50 * scores["TP"] - 5 * (scores["TP"] + scores["FP"])
print(scores.round(3))

#| **ROC curve by hand:** sort by probability, lower the threshold one client at a time, and track the true- and false-positive rates.
o = np.argsort(-p, kind="stable")
tpr = np.r_[0, np.cumsum(y[o] == 1) / (y == 1).sum()]
fpr = np.r_[0, np.cumsum(y[o] == 0) / (y == 0).sum()]
grid = np.linspace(0, 1, 101)
viz_lines(grid, Logit=np.interp(grid, fpr, tpr), **{"Coin flip": grid},
          xlab="False-positive rate (share of non-buyers called)", ylab="True-positive rate (share of buyers reached)",
          title="The model's ROC curve bows well above a coin flip")

#| **AUC** by the trapezoid rule, checked against scikit-learn's `roc_auc_score`.
from sklearn.metrics import roc_auc_score
auc = np.trapezoid(tpr, fpr) if hasattr(np, "trapezoid") else np.trapz(tpr, fpr)
print(round(auc, 5), round(roc_auc_score(y, p), 5))

#| **Gain table by decile, plus lift and Gini** (2·AUC − 1).
decile = np.ceil(10 * np.arange(1, len(o) + 1) / len(o)).astype(int)
gain = pd.DataFrame({"called": [f"{10*k}%" for k in range(1, 11)],
                     "buyers": pd.Series(y[o]).groupby(decile).sum().to_numpy()})
gain["cum_gain"] = gain["buyers"].cumsum() / y.sum()
gain["lift"] = gain["cum_gain"] / (np.arange(1, 11) / 10)
print(gain.round(4)); print("gini", round(2 * auc - 1, 4))

#| **Is that AUC luck?** Repeat on 50 random stratified splits. Python's random numbers differ from R's, so the range differs slightly from the R tab, but the lesson is the same: report a range.
rng = np.random.default_rng(3371)
yes_i, no_i = np.flatnonzero(bank["yes"] == 1), np.flatnonzero(bank["yes"] == 0)
aucs = []
for _ in range(50):
    te = np.r_[rng.choice(yes_i, 136, replace=False), rng.choice(no_i, 1101, replace=False)]
    tr = np.setdiff1d(np.arange(len(bank)), te)
    m = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m", bank.iloc[tr]).fit(disp=0)
    aucs.append(roc_auc_score(bank["yes"].iloc[te], m.predict(bank.iloc[te])))
print(np.quantile(aucs, [0.05, 0.5, 0.95]).round(3))
