_m = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m", train).fit(disp=0)
_p = _m.predict(test)
_call = _p >= _p.quantile(0.80)
_rec = (_call & (test["yes"] == 1)).sum() / (test["yes"] == 1).sum()
_prec = (_call & (test["yes"] == 1)).sum() / _call.sum()
_base = test["yes"].mean()
try:
    _ok_p = len(p) == len(test) and bool(((p >= 0) & (p <= 1)).all())
except Exception:
    _ok_p = False
try:
    _ok_rp = abs(float(recall) - _rec) < 1e-9 and abs(float(precision) - _prec) < 1e-9
except Exception:
    _ok_rp = False
check_that(_ok_p and _ok_rp,
    f"Calling {int(_call.sum())} clients (20% of the list) reaches {100*_rec:.0f}% of all subscribers, {_rec/0.2:.1f} times what random calling would find: that ratio is the lift. "
    f"Precision is {100*_prec:.0f}% against an {100*_base:.0f}% base rate, and precision divided by the base rate is the same {_prec/_base:.1f}. "
    "Lift and precision are two views of one fact. Now change 0.80 to 0.70: how many more subscribers do the extra calls find?",
    "Your p is not a vector of probabilities: use smf.logit and .predict()." if not _ok_p else
    "Recall divides the subscribers you reached by ALL subscribers in the test set: (test['yes'] == 1).sum().")
