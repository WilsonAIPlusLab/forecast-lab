# Hidden check for ex_memory: recompute the three numbers and compare.
_a = dict(zip(fit.param_names, fit.params))["smoothing_level"]; _b = fit.states["trend"].iloc[-1]
_ok = all(k in globals() for k in ("alpha", "half_life", "slope")) and abs(alpha - _a) < 1e-8 and abs(half_life - np.log(0.5) / np.log(1 - _a)) < 1e-6 and abs(slope - _b) < 1e-6
check_that(_ok,
  f"Your note to the manager: alpha = {_a:.2f}, so the newest month alone carries about {round(100 * _a)}% of the level's weight and its half-life is about {np.log(0.5) / np.log(1 - _a):.1f} month; the level's information is on average only {1 / _a:.1f} months old. Underlying online sales were growing by about ${round(_b)} million a month in August 2025 (about ${12 * _b / 1000:.1f} billion a year, before seasonal swings). statsmodels' estimates differ a little from R's (alpha 0.50, slope $522 million) because the optimizers differ.",
  "Check the blanks: the parameter is \"smoothing_level\"; the half-life formula uses the alpha you just stored; and the slope column of fit.states is \"trend\".")
