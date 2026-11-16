# Hidden check for ex_cost: recompute both costs, and the cost of seasonal naive with a 5% buffer.
.c <- function(fc) { d <- test - fc; mean(ifelse(d > 0, 4 * d, -d)) }
.t <- c(.c(f_sn), .c(f_nv)); .b <- .c(1.05 * f_sn)
check_that(exists("costs") && is.numeric(costs) && length(costs) == 2 && all(abs(costs - .t) < 1e-6),
  sprintf("Cost: seasonal naive %s, naive %s. Under MAE seasonal naive wins easily, but under a 4-to-1 cost naive wins, only because it is too high in most months: it repeats December's peak all year. The better fix is to keep the good forecast and shade it up: seasonal naive plus a 5%% buffer costs %s. (Choose such a buffer on past data, not on the test set.)", format(round(.t[1]), big.mark = ","), format(round(.t[2]), big.mark = ","), format(round(.b), big.mark = ",")),
  "An under-forecast (e > 0) costs 4 per unit, so the first blank is 4. An over-forecast has e < 0, and its cost must be positive, so the second blank is -e.")
