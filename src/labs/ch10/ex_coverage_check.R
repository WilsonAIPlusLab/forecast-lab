# Hidden check for ex_coverage: recomputes the audit and compares.
.in <- actual >= lo & actual <= hi
.ok <- exists("inside") && exists("coverage") && exists("below") && length(inside) == 24 && all(inside == .in) &&
  abs(coverage - 100 * mean(.in)) < 1e-9 && below == sum(actual < lo)
check_that(.ok,
  sprintf("%d of 24 months inside: %.1f%% coverage against a promise of 80%%. Misses: %d above, %d below. Is that good? Even an honest 80%% band lands between 16 and 22 hits in 24 months about 9 times in 10, so %d is %s. Now look at the sides: an honest band misses about equally often above and below. More misses on one side would mean the forecast itself is biased. Try start = 2015: the band now remembers the 2020 swings and covers all 24 months, which sounds great but means it is too wide.",
          sum(.in), 100 * mean(.in), sum(actual > hi), sum(actual < lo), sum(.in),
          if (sum(.in) >= 16 && sum(.in) <= 22) "well within the normal range" else "outside the normal range"),
  "Check the blanks. A hit needs actual >= lo AND actual <= hi. Coverage is 100 * mean(inside). For misses below the band, count the months where actual < lo.")
