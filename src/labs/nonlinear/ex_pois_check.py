_m = smf.glm("cnt ~ yr + temp", rush, family=sm.families.Poisson()).fit()
_d = _m.pearson_chi2 / _m.df_resid
try:
    _ok = abs(float(dispersion) - _d) < 1e-6
except Exception:
    _ok = False
check_that(_ok,
    f"Dispersion = {_d:.0f}. At 8 a.m. the counts vary about {_d:.0f} times more than a Poisson model allows (at 4 a.m. the same check gives about 1.7). "
    f"Busy hours are shaped by things the model does not see, such as a Metro delay, a big event or a sudden shower. A negative binomial or quasi-Poisson model is the honest choice, "
    f"and its standard errors (and, roughly, its prediction intervals) will be about sqrt({_d:.0f}) = {np.sqrt(_d):.0f} times wider.",
    "Check two things: the family is sm.families.Poisson(), and the dispersion uses the Pearson chi-square (m.pearson_chi2) divided by m.df_resid.")
