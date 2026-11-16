# Hidden check for ex_windows: recompute the year-by-year MAEs.
.u <- fred("UNRATE", start = 2005, quiet = TRUE)
.r <- t(sapply(2010:2018, function(yr) { tr <- window(.u, end = c(yr, 12)); te <- window(.u, start = c(yr + 1, 1), end = c(yr + 1, 12))
  c(naive = mean(abs(te - naive(tr, h = 12)$mean)), drift = mean(abs(te - rwf(tr, h = 12, drift = TRUE)$mean))) }))
.w <- sum(.r[, 1] < .r[, 2])
check_that(exists("res") && exists("wins_naive") && isTRUE(all.equal(unname(res), unname(.r))) && wins_naive == .w,
  sprintf("Naive wins %d of 9 test years and drift wins %d. Drift won every year from 2016 to 2019, when unemployment fell steadily, so an analyst who tested only on 2019 would crown drift. Over all nine years naive misses less on average (%.2f vs %.2f percentage points). One test year is an anecdote; many test windows are evidence.", .w, 9 - .w, mean(.r[, 1]), mean(.r[, 2])),
  "The test year must come right after the training data, so nxt is yr + 1. To count naive's wins, compare with <: naive's MAE smaller than drift's.")
