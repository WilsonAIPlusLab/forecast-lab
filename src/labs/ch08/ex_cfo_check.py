# Hidden check for ex_cfo: recomputes the answers and writes the sentence for the CFO.
_m = smf.logit("rec_ahead ~ spread", data=known).fit(disp=0)
_l = d.tail(1)
_p0 = float(_m.predict(_l).iloc[0])
_pf = float(_m.predict(pd.DataFrame({"spread": _l["spread"] - 0.25})).iloc[0])
_b = float(known["rec_ahead"].mean())
_me = 100 * float(_m.params["spread"]) * _p0 * (1 - _p0)
_dt = pd.Timestamp(_l.index[0])
try:
    _ok_p = abs(float(p_now) - _p0) < 1e-9
except Exception:
    _ok_p = False
try:
    _ok_f = abs(float(p_flat) - _pf) < 1e-9
except Exception:
    _ok_f = False
try:
    _ok_r = abs(float(change_pp) - 100 * (_pf - _p0)) < 1e-6 and abs(float(base) - _b) < 1e-9
except Exception:
    _ok_r = False
check_that(_ok_p and _ok_f and _ok_r,
    f"For the CFO: 'With the 10-year yield {float(_l['spread'].iloc[0]):.2f} points above the 3-month bill in {_dt:%B %Y}, the model puts the chance that "
    f"{(_dt + pd.DateOffset(months=12)):%B %Y} is a recession month at {100*_p0:.1f}%, about 1 in {round(1/_p0)}. "
    f"That is {_p0/_b:.1f} times the {100*_b:.1f}% base rate since 1959: slightly below normal risk. "
    f"If the curve flattened by 25 basis points, it would rise to {100*_pf:.1f}% (+{100*(_pf-_p0):.1f} percentage points).' "
    f"Check with the marginal effect: b x p(1 - p) = {_me:.1f} pp per point, times 0.25 = {-_me*0.25:.1f} pp, close because the S-curve is nearly straight over a quarter point.",
    "p_now should be a probability: use smf.logit." if not _ok_p else
    "25 basis points is 0.25 percentage points, the unit of the spread. Subtract 0.25, not 25." if not _ok_f else
    "The base rate is the mean of the 0/1 target column, rec_ahead.")
