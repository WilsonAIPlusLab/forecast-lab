# Hidden check (not shown to students): recomputes the SHAP forecast and confirms the two blanks.
_truth = nov["lag1"].iloc[0] * (1 + fit.predict(dnov)[0] / 100)
_S = pd.Series(fit.predict(dnov, pred_contribs=True)[0], index=features + ["base"])
_drag = _S[biggest_drag] * nov["lag1"].iloc[0] / 100 / 1000
check_that(len(S) == len(features) + 1 and abs(forecast_from_shap - _truth) < 1,
    f"The SHAP values add up exactly to the model's own forecast, ${_truth / 1000:.1f}bn (actual: ${nov['sales'].iloc[0] / 1000:.1f}bn). "
    f"The biggest drag was `{biggest_drag}` (November 2025 had {int(nov['weekend'].iloc[0])} weekend days): it lowered the forecast by ${abs(_drag):.1f}bn. "
    "Is that causal? Not necessarily. SHAP explains what the model learned, not why shoppers behave as they do.",
    "Two things to check: pred_contribs must be True, and the second blank must add up every value in S, base value included, for example S.sum().")
