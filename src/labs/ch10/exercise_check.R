.cr <- cu / (cu + co)
.q <- unname(quantile(demand, .cr))
check_that(exists("cr") && abs(cr - .cr) < 1e-9 && exists("stock") && abs(stock - .q) < 1e-6,
  sprintf("Critical ratio = %.2f, so stock %s ($ millions), which is %s below the median forecast. When leftovers cost more than shortages, the best plan deliberately runs out in about %.0f%% of scenarios. Safety stock can be negative.",
          .cr, format(round(.q), big.mark = ","), format(round(median(demand) - .q), big.mark = ","), 100 * (1 - .cr)),
  "Check both blanks. The critical ratio is cu / (cu + co): the cost of running short divided by the total of both costs. Then pass that ratio (the object cr) as the probability in quantile().")
