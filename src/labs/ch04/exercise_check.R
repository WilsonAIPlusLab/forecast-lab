.truth <- unname(coef(fit)["mr"] * (5 - now$mr))
check_that(exists("gap") && is.numeric(gap) && abs(unname(gap) - .truth) < 1e-6,
  sprintf("Right: about %s million more cars a year. That is exactly the mortgage-rate slope (%s) times the change in the rate (5 − %s = %s points). In a linear model a scenario gap is always slope × change. But look at the intervals: each one runs about 2.5 million either side of its forecast, so the gap is smaller than the uncertainty around either forecast. And rates rarely fall 2.3 points while unemployment stays put, so ask whether your scenario is internally consistent.",
          format(round(.truth, 2), nsmall = 2), round(coef(fit)["mr"], 3), round(now$mr, 2), round(5 - now$mr, 2)),
  "Check both blanks: the low-rate scenario needs mr = 5, and the second predict() call should use the low_rate data frame. The gap is low-rate minus today.")
