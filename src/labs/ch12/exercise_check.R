.p <- predict(fit, dnov); .truth <- nov$lag1 * (1 + .p / 100)
.S <- predict(fit, dnov, predcontrib = TRUE); .drag <- .S[1, biggest_drag] * nov$lag1 / 100 / 1000
check_that(is.matrix(S) && ncol(S) == length(features) + 1 && exists("forecast_from_shap") && abs(forecast_from_shap - .truth) < 1,
  sprintf("The SHAP values add up exactly to the model's own forecast, $%.1fbn (actual: $%.1fbn). The biggest drag was `%s` (November 2025 had %d weekend days): it lowered the forecast by $%.1fbn. Is that causal? Not necessarily. SHAP explains what the model learned, not why shoppers behave as they do.",
          .truth / 1000, nov$sales / 1000, biggest_drag, as.integer(nov$weekend), abs(.drag)),
  "Two things to check: predcontrib must be TRUE (not the string \"TRUE\"), and the second blank must add up every column of S, base value included, for example sum(S).")
