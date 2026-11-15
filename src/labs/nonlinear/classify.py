#| **Score the clients the model has never seen.** Fit on the training clients (hidden setup: same data and split as before), then predict a probability for each of the 1,237 test clients: the next campaign's call list.
# logistic regression: models the probability that yes = 1
logit = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m", train).fit(disp=0)
p = logit.predict(test).to_numpy()         # predicted probabilities (0 to 1) for each test client
y = test["yes"].to_numpy()                 # what actually happened: 1 = subscribed, 0 = did not
print(pd.Series(p).describe().round(4))    # spread of the predicted probabilities

#| **Confusion matrix at 0.5.** `pd.crosstab` counts predictions against outcomes. Very few clients reach 50%, so the model rarely says yes.
pred50 = (p > 0.5).astype(int)             # 1 if probability above 0.5, else 0
print(pd.crosstab(pd.Series(pred50, name="predicted"), pd.Series(y, name="actual")))   # rows = predicted, columns = actual

#| **Five metrics from one table**, written out so every formula is visible.
def metrics(pred, y):
    # the four cells: true/false positives and negatives
    TP = int(((pred == 1) & (y == 1)).sum()); FP = int(((pred == 1) & (y == 0)).sum())
    FN = int(((pred == 0) & (y == 1)).sum()); TN = int(((pred == 0) & (y == 0)).sum())
    precision = TP / (TP + FP) if TP + FP > 0 else np.nan   # undefined if we never say yes
    recall = TP / (TP + FN)
    return dict(TP=TP, FP=FP, FN=FN, TN=TN, accuracy=(TP + TN) / len(y), precision=precision, recall=recall,
                specificity=TN / (TN + FP), F1=2 * precision * recall / (precision + recall) if TP > 0 else np.nan)

#| **The accuracy paradox.** Always-no is 89% accurate and finds nobody. The 0.10 threshold is the break-even point if a call costs \$5 and a deposit is worth \$50 (illustrative numbers); `profit` applies them.
# four rules: model at 0.5, model at 0.10, call everyone (all 1s), always say no (all 0s)
rules = {"Logit, threshold 0.5": pred50, "Logit, threshold 0.10": (p > 0.10).astype(int),
         "Call everyone": np.ones_like(y), "Always say no": np.zeros_like(y)}
scores = pd.DataFrame({k: metrics(v, y) for k, v in rules.items()}).T   # one row per rule
scores["profit"] = 50 * scores["TP"] - 5 * (scores["TP"] + scores["FP"])   # $50 per subscriber minus $5 per call
print(scores.round(3))

#| **ROC curve by hand:** sort by probability, lower the threshold one client at a time, and track the true- and false-positive rates.
o = np.argsort(-p, kind="stable")          # client positions, highest probability first
tpr = np.r_[0, np.cumsum(y[o] == 1) / (y == 1).sum()]   # running share of yeses caught (starts at 0)
fpr = np.r_[0, np.cumsum(y[o] == 0) / (y == 0).sum()]   # running share of noes called
grid = np.linspace(0, 1, 101)              # 101 evenly spaced false-positive rates for plotting
# np.interp reads the curve's TPR at each grid point; the diagonal is a coin flip
viz_lines(grid, Logit=np.interp(grid, fpr, tpr), **{"Coin flip": grid},
          xlab="False-positive rate (share of non-buyers called)", ylab="True-positive rate (share of buyers reached)",
          title="The model's ROC curve bows well above a coin flip")

#| **AUC** by the trapezoid rule, checked against scikit-learn's `roc_auc_score`.
from sklearn.metrics import roc_auc_score
auc = np.trapezoid(tpr, fpr) if hasattr(np, "trapezoid") else np.trapz(tpr, fpr)   # newer NumPy renamed trapz
print(round(auc, 5), round(roc_auc_score(y, p), 5))   # the two should match

#| **Gain table by decile, plus lift and Gini** (2·AUC − 1).
decile = np.ceil(10 * np.arange(1, len(o) + 1) / len(o)).astype(int)   # 1 = top 10% of the ranked list, ..., 10 = bottom
gain = pd.DataFrame({"called": [f"{10*k}%" for k in range(1, 11)],   # labels "10%" ... "100%"
                     "buyers": pd.Series(y[o]).groupby(decile).sum().to_numpy()})   # subscribers in each decile
gain["cum_gain"] = gain["buyers"].cumsum() / y.sum()   # share of all subscribers found so far
gain["lift"] = gain["cum_gain"] / (np.arange(1, 11) / 10)   # vs. random calling, which finds 10%, 20%, ...
print(gain.round(4)); print("gini", round(2 * auc - 1, 4))

#| **Is that AUC luck?** Repeat on 50 random stratified splits. Python's random numbers differ from R's, so the range differs slightly from the R tab, but the lesson is the same: report a range.
rng = np.random.default_rng(3371)          # fixed seed: the same 50 splits every run
yes_i, no_i = np.flatnonzero(bank["yes"] == 1), np.flatnonzero(bank["yes"] == 0)   # row positions of yeses and noes
aucs = []
for _ in range(50):                        # 50 repetitions (_ = loop counter we don't need)
    # stratified test set: 136 random yeses + 1,101 random noes, the same mix as the original split
    te = np.r_[rng.choice(yes_i, 136, replace=False), rng.choice(no_i, 1101, replace=False)]
    tr = np.setdiff1d(np.arange(len(bank)), te)   # training rows = everything not in the test set
    m = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m", bank.iloc[tr]).fit(disp=0)
    aucs.append(roc_auc_score(bank["yes"].iloc[te], m.predict(bank.iloc[te])))   # test AUC for this split
print(np.quantile(aucs, [0.05, 0.5, 0.95]).round(3))   # 5th percentile, median, 95th percentile
