#| **Fit the logit and get in-sample probabilities.** `y` is the actual outcome.
import statsmodels.api as sm
logit = sm.Logit(known["rec_ahead"], sm.add_constant(known[["spread"]])).fit(disp=0)
p = logit.predict()
y = known["rec_ahead"].to_numpy()
print("months:", len(y), "| recession months:", int(y.sum()), "| base rate:", round(y.mean(), 3))

#| **Confusion matrix at a 0.5 threshold.**
call = (p >= 0.5).astype(int)
print(pd.crosstab(pd.Series(call, name="Called"), pd.Series(y.astype(int), name="Actual")))

#| **Hit rate and false alarm rate** at three thresholds.
def rates(th):
    return {"threshold": th, "hit_rate": (p[y == 1] >= th).mean(), "false_alarm_rate": (p[y == 0] >= th).mean()}
print(pd.DataFrame([rates(0.5), rates(0.3), rates(0.2)]).round(4))

#| **ROC curve by hand**, sweeping every threshold. scikit-learn's `roc_curve` does the same thing.
th = np.r_[np.inf, np.sort(np.unique(p))[::-1], -np.inf]
tpr = np.array([(p[y == 1] >= t).mean() for t in th])
fpr = np.array([(p[y == 0] >= t).mean() for t in th])
viz_lines(fpr, **{"Yield-curve logit": tpr, "Coin flip": fpr}, xlab="False alarm rate", ylab="Hit rate",
          title="The spread separates pre-recession months from calm ones far better than chance")

#| **AUC** by the trapezoid rule, checked against scikit-learn.
from sklearn.metrics import roc_auc_score
auc = np.sum(np.diff(fpr) * (tpr[:-1] + tpr[1:]) / 2)
print("AUC by hand:", round(auc, 4), "| sklearn:", round(roc_auc_score(y, p), 4))

#| **Brier score** against the climatology benchmark, and the skill score.
brier = np.mean((p - y) ** 2)
brier_climo = np.mean((y.mean() - y) ** 2)
print("Brier:", round(brier, 4), "| climatology:", round(brier_climo, 4), "| skill:", round(1 - brier / brier_climo, 4))

#| **Calibration table.**
bins = pd.cut(p, [0, 0.1, 0.2, 0.4, 0.6, 1], include_lowest=True)
calib = pd.DataFrame({"p": p, "y": y, "bin": bins}).groupby("bin", observed=False).agg(
    **{"Months": ("y", "size"), "Average forecast": ("p", "mean"), "Share followed by recession": ("y", "mean")})
calib.insert(0, "Forecast range", calib.index.astype(str))
calib = calib.reset_index(drop=True)
print(calib.round(3))
viz_table(calib, digits=3, title="Well calibrated below 20%, overconfident above 40%")
