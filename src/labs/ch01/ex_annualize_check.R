# Hidden check for ex_annualize: annualized quarterly growth matches BEA's published rate; log change is close to % change.
.g <- fred("GDPC1", quiet = TRUE); .b <- as.numeric(tail(fred("A191RL1Q225SBEA", quiet = TRUE), 1))
.q <- as.numeric(tail(.g, 2)); .q5 <- as.numeric(tail(.g, 5))[1]
.gq <- 100 * (.q[2] / .q[1] - 1); .ga <- 100 * ((.q[2] / .q[1])^4 - 1); .gl <- 100 * log(.q[2] / .q[1])
.ok_a <- exists("g_ann") && isTRUE(abs(g_ann - .ga) < 1e-8)
.ok_l <- exists("g_log") && isTRUE(abs(g_log - .gl) < 1e-8)
.fail <- if (exists("g_ann") && isTRUE(abs(g_ann - .gq * 4) < 1e-6)) "You multiplied by 4. Annualizing compounds: raise the growth factor to the 4th power." else
  if (!.ok_a) "Blank 1: a year has 4 quarters, so raise q[2]/q[1] to the power 4." else
  "Blank 2: the log change is log(q[2]) - log(q[1])."
check_that(.ok_a && .ok_l,
  sprintf("Both numbers are right. GDP grew %.2f%% from the previous quarter, which compounds to %.2f%% at an annual rate; BEA rounds that to %.1f%%. The log change, %.2f, is within %.3f of the percent change, as it should be for a small move. To go back from an annual rate to a quarterly one, take the 4th root: 100 x (%.3f^(1/4) - 1) = %.2f%%. Over the past four quarters GDP grew %.1f%%: that is the year-over-year view.",
          .gq, .ga, .b, .gl, abs(.gq - .gl), 1 + .b / 100, 100 * ((1 + .b / 100)^(1/4) - 1), 100 * (.q[2] / .q5 - 1)),
  .fail)
