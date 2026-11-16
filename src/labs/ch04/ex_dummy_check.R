# Hidden check: compares the student's two percent gaps with the truth.
.b <- coef(tslm(train ~ trend + season + covid, lambda = 0))
.dj <- 100 * (exp(.b[["season12"]]) - 1); .dn <- 100 * (exp(.b[["season12"]] - .b[["season11"]]) - 1)
.ok <- exists("dec_vs_jan") && exists("dec_vs_nov") && abs(unname(dec_vs_jan) - .dj) < 1e-6 && abs(unname(dec_vs_nov) - .dn) < 1e-6
check_that(.ok,
  sprintf("Right. December runs %.1f%% above January and %.1f%% above November, holding the trend fixed. Two lessons: (1) a dummy's coefficient is always a gap from the base month, so to compare two other months you subtract their coefficients first; (2) for big log coefficients the shortcut 100 × b misleads: December's b is %.3f, which reads as %.1f%% but is really %.1f%%.",
          .dj, .dn, .b[["season12"]], 100 * .b[["season12"]], .dj),
  if (exists("dec_vs_jan") && abs(unname(dec_vs_jan) - .dj) < 1e-6)
    "December vs January is right. For December vs November, subtract November's coefficient, b[\"season11\"], inside exp()."
  else "December's coefficient is named \"season12\" (season2 is February, so season12 is December). Put the name in quotes inside b[ ].")
