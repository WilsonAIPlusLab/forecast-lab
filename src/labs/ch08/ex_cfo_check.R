# Hidden check for ex_cfo: recomputes the answers and writes the sentence for the CFO.
.m <- glm(rec_ahead ~ spread, data = known, family = binomial)
.l <- tail(d, 1)
.p0 <- predict(.m, newdata = .l, type = "response")
.pf <- predict(.m, newdata = data.frame(spread = .l$spread - 0.25), type = "response")
.b <- mean(known$rec_ahead)
.me <- 100 * coef(.m)[["spread"]] * .p0 * (1 - .p0)
.tgt <- seq(.l$date, by = "12 months", length.out = 2)[2]
.ok_p <- exists("p_now") && is.numeric(p_now) && abs(p_now - .p0) < 1e-9
.ok_f <- exists("p_flat") && is.numeric(p_flat) && abs(p_flat - .pf) < 1e-9
check_that(.ok_p && .ok_f && exists("change_pp") && abs(change_pp - 100 * (.pf - .p0)) < 1e-6 && exists("base") && abs(base - .b) < 1e-9,
  sprintf(paste0("For the CFO: 'With the 10-year yield %.2f points above the 3-month bill in %s, the model puts the chance that %s is a recession month at %.1f%%, about 1 in %d. ",
                 "That is %.1f times the %.1f%% base rate since 1959: slightly below normal risk. If the curve flattened by 25 basis points, it would rise to %.1f%% (+%.1f percentage points).' ",
                 "Check with the marginal effect: b x p(1 - p) = %.1f pp per point, times 0.25 = %.1f pp, close because the S-curve is nearly straight over a quarter point."),
          .l$spread, format(.l$date, "%B %Y"), format(.tgt, "%B %Y"), 100 * .p0, round(1 / .p0),
          .p0 / .b, 100 * .b, 100 * .pf, 100 * (.pf - .p0), .me, -.me * 0.25),
  if (!.ok_p) "p_now should be a probability: a logit needs family = binomial." else
  if (!.ok_f) "25 basis points is 0.25 percentage points, the unit of the spread. Subtract 0.25, not 25." else
  "The base rate is the mean of the 0/1 target column, rec_ahead.")
