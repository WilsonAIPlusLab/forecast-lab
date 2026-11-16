# Hidden check for ex_logs: the log model scored in $ millions, plus the (wrong) log-scale MAE for the message.
_lt = np.log(train.values); _s = (_lt[-1] - _lt[0]) / (len(_lt) - 1)
_fb = np.exp(_lt[-1] + _s * np.arange(1, h + 1)); _t = np.abs(test.values - _fb).mean()
_ls = (train.values[-1] - train.values[0]) / (len(train) - 1); _l = np.abs(test.values - (train.values[-1] + _ls * np.arange(1, h + 1))).mean()
_g = 100 * (np.exp(12 * _s) - 1); _w = np.abs(np.log(test.values) - np.log(_fb)).mean()
_ok = False
try:
    _ok = abs(float(mae_log) - _t) < 1e-6
except Exception:
    pass
check_that(_ok,
    f"In $ millions: drift on levels misses by {_l:,.0f} a month, drift on logs by {_t:,.0f}. The log model assumed the 2015-22 growth rate ({_g:.1f}% a year, boosted by the 2020 jump) would continue, and it did not. Had you scored the log model on the log scale, you would have reported {_w:.3f}, a number that cannot be compared with {_l:,.0f} at all. Always transform back, then score in the original units.",
    "np.log() is undone by np.exp(). Then score the back-transformed forecast f_back against test, so both MAEs are in $ millions.")
