# Hidden check for ex_cumulative: recompute the multipliers from the same ADL(1,1).
suppressMessages(library(dynlm))
.dj <- diff(fred("PAYEMS")); .dcl <- 100 * diff(log(fred("ICSA", to = "month")))
.b <- coef(dynlm(.dj ~ L(.dj, 1) + L(.dcl, 0:1), start = c(1990, 1), end = c(2019, 12)))
.m0 <- .b[[3]]; .m1 <- .b[[4]] + .b[[2]] * .m0; .m2 <- .b[[2]] * .m1; .c3 <- 10 * (.m0 + .m1 + .m2)
.ok1 <- exists("m1") && is.numeric(m1) && length(m1) == 1 && abs(m1 - .m1) < 1e-6
.ok2 <- exists("m2") && is.numeric(m2) && length(m2) == 1 && abs(m2 - .m2) < 1e-6
check_that(.ok1 && .ok2,
  sprintf("Right. A lasting 10%% jump in claims goes with about %s fewer jobs added this month, %s fewer next month and %s fewer the month after: about %s fewer jobs in total after three months. That total is the cumulative effect, %.1f times the impact. When you report a number, say which one it is.",
          format(round(-10 * .m0 * 1000, -3), big.mark = ","), format(round(-10 * .m1 * 1000, -3), big.mark = ","),
          format(round(-10 * .m2 * 1000, -3), big.mark = ","), format(round(-.c3 * 1000, -3), big.mark = ","), .c3 / (10 * .m0)),
  if (!.ok1) "Month 1 has two parts: the lagged claims coefficient b1, plus phi times the month-0 response m0."
  else "Month 1 is right. In month 2 there is no claims coefficient left (the model stops at lag 1), so only the echo phi * m1 remains.")
