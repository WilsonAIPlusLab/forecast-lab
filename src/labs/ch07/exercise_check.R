suppressMessages(library(dynlm))
.dj <- diff(fred("PAYEMS")); .dcl <- 100 * diff(log(fred("ICSA", to = "month")))
.b <- coef(dynlm(.dj ~ L(.dj, 1) + L(.dcl, 0:1), start = c(1990, 1), end = c(2019, 12)))
.imp <- unname(.b[3]); .lr <- unname((.b[3] + .b[4]) / (1 - .b[2]))
.ok_imp <- exists("impact") && is.numeric(impact) && abs(unname(impact) - .imp) < 1e-6
.ok_lr  <- exists("long_run") && is.numeric(long_run) && abs(unname(long_run) - .lr) < 1e-6
check_that(.ok_imp && .ok_lr,
  sprintf("Impact = %.1f and long run = %.1f thousand jobs per 1%% rise in claims. So a 10%% jump in claims that persists costs about %s jobs in total, roughly %.1f times the first month's effect. That ratio is 1/(1 − φ) magnified by the lagged claims term: the more persistent job growth is, the further a shock echoes.",
          .imp, .lr, format(round(-10 * .lr * 1000, -3), big.mark = ","), .lr / .imp),
  if (!.ok_imp) "Check the impact multiplier: it is the coefficient on claims growth at lag 0, the third element of b (b[3])."
  else "The impact is right. For the long run, add BOTH claims coefficients, b[3] + b[4], in parentheses before dividing by (1 - b[2]).")
