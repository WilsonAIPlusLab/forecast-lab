# Hidden check: compares the student's elasticity and percent effects with the truth.
.m <- lm(log(veh) ~ log(gas) + un + mr + chip, data = d); .b <- unname(coef(.m)["log(gas)"])
.ok <- exists("b_gas") && exists("pct_approx") && exists("pct_exact") &&
  abs(b_gas - .b) < 1e-8 && abs(pct_approx - 20 * .b) < 1e-6 && abs(pct_exact - 100 * (1.2^.b - 1)) < 1e-6
check_that(.ok,
  sprintf("Right. The elasticity is %.3f, so a 20%% rise in gas goes with about %.2f%% fewer sales (exact: %.2f%%), holding jobs and rates fixed. On today's 16.0 million that is about %s cars a year. Notice how small an elasticity of %.3f is: car demand is very inelastic to fuel prices in the short run, because people still need cars. For small changes the rule of thumb and the exact formula agree; for big ones (gas doubling) use the exact one.",
          .b, 20 * .b, 100 * (1.2^.b - 1), format(round(-tail(d[, "veh"], 1) * (1.2^.b - 1) * 1e6, -3), big.mark = ","), .b),
  "Check the blanks: the model needs log(gas) (not gas) so its coefficient is an elasticity; the rule of thumb multiplies by 20 (percent, not 0.20); the exact formula raises 1.20 to the power of the elasticity.")
