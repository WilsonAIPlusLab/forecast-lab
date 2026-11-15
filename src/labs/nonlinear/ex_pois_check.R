.m <- glm(cnt ~ yr + temp, family = poisson, data = rush)
.d <- sum(residuals(.m, type = "pearson")^2) / df.residual(.m)
check_that(exists("dispersion") && is.numeric(dispersion) && abs(dispersion - .d) < 1e-6,
  sprintf("Dispersion = %.0f. At 8 a.m. the counts vary about %.0f times more than a Poisson model allows (at 4 a.m. the same check gives about 1.7). Busy hours are shaped by things the model does not see, such as a Metro delay, a big event or a sudden shower. A negative binomial (MASS::glm.nb) or quasi-Poisson model is the honest choice here, and its standard errors (and, roughly, its prediction intervals) will be about sqrt(%.0f) = %.1f times wider.", .d, .d, .d, sqrt(.d)),
  "Check two things: a count model needs family = poisson, and the dispersion statistic uses Pearson residuals (type = \"pearson\") divided by the residual degrees of freedom, df.residual(m).")
