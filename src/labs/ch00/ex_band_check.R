# Hidden check for ex_band: recompute the December numbers and compare.
.k <- which(cycle(fc$mean) == 12)[1]
.ok <- exists("point_bn") && exists("high80_bn") && exists("low80_bn") &&
  isTRUE(abs(point_bn - fc$mean[.k] / 1000) < 1e-6) && isTRUE(abs(high80_bn - fc$upper[.k, "80%"] / 1000) < 1e-6)
check_that(.ok,
  sprintf("A manager-ready sentence: \"We expect December retail sales of about $%.0f billion. We would not be surprised by anything from $%.0f to $%.0f billion; outside that range would be a 1-in-5 surprise.\" Notice the band is about $%.0f billion wide: that range, not the point, is the honest message.",
          fc$mean[.k] / 1000, fc$lower[.k, "80%"] / 1000, fc$upper[.k, "80%"] / 1000, (fc$upper[.k, "80%"] - fc$lower[.k, "80%"]) / 1000),
  "Two blanks. The data are in $ millions, so divide by 1000 to get $ billions. The top of the band lives in fc$upper, the twin of fc$lower.")
