_r = d["rec"].to_numpy(); _n = len(_r)
_tw = np.array([_r[i + 1:i + 13].max() if i + 12 < _n else np.nan for i in range(_n)])
_u = d.assign(_t=_tw).dropna(subset=["_t"])
import statsmodels.formula.api as _smf
from sklearn.metrics import roc_auc_score as _auc
_a = _auc(_u["_t"], _smf.logit("_t ~ spread", data=_u).fit(disp=0).predict(_u))
_k = d.dropna(subset=["rec_ahead"])
_aa = _auc(_k["rec_ahead"], _smf.logit("rec_ahead ~ spread", data=_k).fit(disp=0).predict(_k))
_ok = False
try:
    _ok = np.allclose(np.asarray(d["rec_within"], dtype=float), _tw, equal_nan=True) and abs(auc_w - _a) < 1e-6
except Exception:
    pass
check_that(_ok,
  f"AUC = {_a:.3f} for 'any recession in the next 12 months', against {_aa:.3f} for 'recession in month t + 12'. The wider window sounds more natural, but it scores worse: it counts the months just before and during a recession as positives, and by then the Fed is usually cutting rates and the curve has steepened again. The spread's signal arrives about a year early, so a target pinned 12 months ahead matches it better. Choosing the target is a modeling decision, not a formality.",
  "Check the two blanks. The slice r[i + 1 : i + 1 + 12] covers months t + 1 to t + 12, so the first blank is 12. The logistic regression function in statsmodels' formula API is smf.logit.")
