# Hidden check for ex_windows: recompute the year-by-year MAEs.
_u = fred("UNRATE", start=2005)
_rows = []
for _y in range(2010, 2019):
    _tr = _u[:f"{_y}-12"]; _te = _u[f"{_y + 1}-01":f"{_y + 1}-12"].values
    _d = _tr.iloc[-1] + (_tr.iloc[-1] - _tr.iloc[0]) / (len(_tr) - 1) * np.arange(1, 13)
    _rows.append((np.abs(_te - _tr.iloc[-1]).mean(), np.abs(_te - _d).mean()))
_r = np.array(_rows); _w = int((_r[:, 0] < _r[:, 1]).sum())
_ok = False
try:
    _ok = np.allclose(res[["naive", "drift"]].values, _r) and int(wins_naive) == _w
except Exception:
    pass
check_that(_ok,
    f"Naive wins {_w} of 9 test years and drift wins {9 - _w}. Drift won every year from 2016 to 2019, when unemployment fell steadily, so an analyst who tested only on 2019 would crown drift. Over all nine years naive misses less on average ({_r[:, 0].mean():.2f} vs {_r[:, 1].mean():.2f} percentage points). One test year is an anecdote; many test windows are evidence.",
    "The test year must come right after the training data, so nxt is yr + 1. To count naive's wins, compare with <: naive's MAE smaller than drift's.")
