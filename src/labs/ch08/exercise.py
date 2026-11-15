# The DataFrame d (spread, rec, rec_ahead) is ready, as in the labs above.
# rec_ahead asks: "is month t + 12 a recession month?"
# Build a different target, rec_within: "is there ANY recession month in t + 1, ..., t + 12?"
import statsmodels.formula.api as smf          # R-style formulas: "y ~ x"
from sklearn.metrics import roc_auc_score      # area under the ROC curve
r = d["rec"].to_numpy()                        # recession indicator as a NumPy array
n = len(r)                                     # number of months
# List comprehension over rows i: .max() of the next months' 0/1 values is 1 if any is a recession; NaN if the window runs past the data
# Blank: how many months the slice should cover
d["rec_within"] = [r[i + 1:i + 1 + ______].max() if i + 12 < n else np.nan for i in range(n)]

# 1. Fit a logit of rec_within on the spread (statsmodels formula API)
# Blank: the formula-API function for logistic regression
fit_w = smf.______("rec_within ~ spread", data=d).fit(disp=0)   # disp=0 hides the optimizer log

# 2. Score it with the AUC on the rows the model used
used = d.dropna(subset=["rec_within"])         # drop the last months with no answer yet
auc_w = roc_auc_score(used["rec_within"], fit_w.predict(used))   # predict() = in-sample probabilities
print(round(auc_w, 3))                         # 0.5 = coin flip, 1 = perfect
