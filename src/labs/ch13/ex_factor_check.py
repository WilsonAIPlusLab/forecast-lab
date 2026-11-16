# Hidden grader: rebuilds the growth-rate panel, standardizes it, and compares the PCA results.
_p = pd.DataFrame({i: 100 * np.log(fred(i, start=2009)).diff() for i in ids})["2010-01":"2019-12"]
_z = (_p - _p.mean()) / _p.std()
_s = np.linalg.svd(_z.values, compute_uv=False) ** 2; _s = _s / _s.sum()
_c = _p - _p.mean(); _u, _rs, _rv = np.linalg.svd(_c.values, full_matrices=False); _rs = _rs**2 / np.sum(_rs**2)
_ok_panel = "panel" in globals() and panel.shape == _p.shape and np.allclose(panel.values, _p.values)
_ok_share = "share" in globals() and len(share) == 5 and abs(share[0] - _s[0]) < 1e-6
check_that(_ok_panel and _ok_share,
    f"Right: component 1 explains {100 * _s[0]:.1f}% of the variance, and all five series load positively. Two lessons for free. "
    f"Skip standardizing and PC 1 'explains' {100 * _rs[0]:.0f}%, but it is almost only vehicle unit sales (loading {abs(_rv[0][3]):.2f}), the noisiest series. "
    f"Use log levels instead of growth rates and PC 1 explains about 95%: that is a shared upward trend, not a shared cycle.",
    "Step 1: growth = 100 * np.log(x).diff(). .diff() takes month-to-month changes of the log." if not _ok_panel else
    "Step 2: standardize with (panel - panel.mean()) / panel.std() before the PCA.")
