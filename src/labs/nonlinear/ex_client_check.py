# Hidden check for ex_client: recomputes the answers and writes the manager's memo.
_m = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m", train).fit(disp=0)
_h = pd.DataFrame({"age": 40, "contact": "cellular", "campaign": 1, "euribor3m": 4.9,
                   "poutcome": pd.Categorical(["nonexistent", "success"], ["nonexistent", "failure", "success"])})
_p = _m.predict(_h).to_numpy()
_or = float(np.exp(_m.params["poutcome[T.success]"]))
_low = _m.predict(_h.assign(euribor3m=0.7)).to_numpy()
_ev0 = _p[0] * 50 - 5
try:
    _ok_p = len(p) == 2 and float(np.max(np.abs(np.asarray(p, dtype=float) - _p))) < 1e-9
except Exception:
    _ok_p = False
try:
    _ok_rest = (abs(float(odds_ratio) - _or) < 1e-6 and abs(float(change_pp) - 100 * (_p[1] - _p[0])) < 1e-6
                and float(np.max(np.abs(np.asarray(ev_call, dtype=float) - (_p * 50 - 5)))) < 1e-9)
except Exception:
    _ok_rest = False
check_that(_ok_p and _ok_rest,
    f"Memo: 'She has a {100*_p[0]:.1f}% chance of saying yes, about {round(100*_p[0])} in 100 clients like her. "
    f"A call is worth {100*_p[0]:.1f}% x $50 - $5 = {'-' if _ev0 < 0 else '+'}${abs(_ev0):.2f}, so on its own it does not pay. "
    f"Had our last campaign with her succeeded, her odds would be {_or:.2f} times as high (exactly exp(b) = {_or:.2f}), lifting her chance to {100*_p[1]:.1f}%, "
    f"+{100*(_p[1]-_p[0]):.1f} percentage points, and the call would be worth +${_p[1]*50-5:.2f}.' "
    f"The odds ratio is the same for every client; the percentage points are not. With Euribor at 0.7% she would start at {100*_low[0]:.1f}%, "
    f"and the same past success would add {100*(_low[1]-_low[0]):.1f} points instead of {100*(_p[1]-_p[0]):.1f}.",
    "p should hold two probabilities between 0 and 1: use the fitted model's .predict(her)." if not _ok_p else
    "Check the odds (p / (1 - p)), the change in percentage points (100 * (p[1] - p[0])) and the expected value (p * 50 - 5).")
