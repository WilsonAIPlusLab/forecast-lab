_ly = train.iloc[-12:].values
_sn = pd.Series([_ly[i % 12] for i in range(len(test))], index=test.index)
_truth = (test - _sn).abs().mean()
_ok = False
try:
    _ok = abs(float(mae) - _truth) < 1e-6
except Exception:
    pass
check_that(_ok,
    f"MAE = {_truth:,.0f}. Every error is positive: this series is seasonally adjusted and growing fast, so 'same month last year' is always too low. Now try drift, a straight line from the first to the last training value: its MAE is roughly 2,000.",
    "Check two things: seasonal naive repeats the last 12 training months, so the first blank is -12; and the error is actual minus forecast, so the second blank is the test set, test.")
