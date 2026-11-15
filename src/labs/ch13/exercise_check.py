# Hidden grader: recomputes the bottom-up forecast and compares it with the student's bu_total.
_fc = pd.DataFrame({c: damped_fc(parts[:"2025-09"][c]) for c in parts.columns}, index=test_total.index).sum(axis=1)
_m1 = float((test_total - _fc).abs().mean()); _m2 = float(np.abs(test_total.values - damped_fc(total[:"2025-09"])).mean())
check_that("bu_total" in globals() and len(bu_total) == 12 and np.allclose(np.asarray(bu_total, float), _fc.values),
    f"Bottom-up MAE = {_m1:,.0f} vs {_m2:,.0f} for the direct total forecast ($ millions). Bonus fact: with a linear method such as drift, bottom-up and direct give exactly the same total, because the slope of a sum is the sum of the slopes. (That holds when the total really equals the sum of its parts in the data.) With ETS, each series gets its own fitted model, so the parts no longer have to add up to the total's forecast. That is when reconciliation matters.",
    "Check two things: forecast from the training data (train), and add the columns of fc_parts row by row with .sum(axis=1).")
