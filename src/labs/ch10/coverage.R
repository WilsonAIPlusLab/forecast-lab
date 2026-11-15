#| **The question.** An 80% interval makes a promise: about 8 times out of 10, the truth lands inside. We can check that promise the same way we checked accuracy in Chapter 3, with a **rolling forecast origin**. Here we use retail sales from 2005 (`RSXFSN`, $ millions, NSA) and stand at every month from December 2014 to July 2026.
library(forecast)
retail  <- fred("RSXFSN", start = 2005)
origins <- seq(2014 + 11/12, 2026 + 6/12, by = 1/12)
length(origins)

#| **The audit loop.** At each origin we forecast 12 months ahead with 80% and 95% intervals, then record whether the actual value 1 month and 12 months later fell inside. To keep the loop fast, the ETS(M,A,M) model is **re-estimated once a year, at each December origin**; in between, `ets(train, model = fit, use.initial.values = TRUE)` keeps the estimated parameters and just updates the model with the new data (like a planner who re-tunes the model once a year).
rows <- NULL; fit <- NULL
for (i in seq_along(origins)) {
  o <- origins[i]
  train <- window(retail, end = o)
  fit <- if (i %% 12 == 1) ets(train, model = "MAM") else ets(train, model = fit, use.initial.values = TRUE)
  fc <- forecast(fit, h = 12, level = c(80, 95))
  for (k in c(1, 12)) {
    t <- o + k / 12
    if (t > tsp(retail)[2] + 1e-6) next
    a <- window(retail, start = t, end = t)[1]
    rows <- rbind(rows, c(h = k, time = t, actual = a, lo80 = fc$lower[k, 1], hi80 = fc$upper[k, 1],
                          lo95 = fc$lower[k, 2], hi95 = fc$upper[k, 2]))
  }
}
audit <- as.data.frame(rows)
audit$in80 <- audit$actual >= audit$lo80 & audit$actual <= audit$hi80
audit$in95 <- audit$actual >= audit$lo95 & audit$actual <= audit$hi95
nrow(audit)

#| **Overall coverage.** Compare each number with its promise (80 or 95). One month ahead, the 80% interval hits its target almost exactly. Twelve months ahead it is too wide, and the 95% intervals fall short at both horizons.
overall <- aggregate(cbind(`80% interval` = in80, `95% interval` = in95) ~ h, data = audit, FUN = function(x) round(100 * mean(x), 1))
overall

#| **Now split by era.** Averages can hide a lot. During 2020–2021 the intervals were far too narrow (the pandemic). Afterwards, the model had *learned* that the world is volatile, so its intervals became too wide. "Right on average" came from being wrong in both directions.
audit$era <- cut(audit$time, c(0, 2020, 2022, 3000), right = FALSE, labels = c("2015–2019", "2020–2021", "2022–2026"))
by_era <- aggregate(cbind(`80% interval` = in80, `95% interval` = in95) ~ era + h, data = audit, FUN = function(x) round(100 * mean(x), 1))
by_era
viz_table(by_era, title = "Coverage (%) by era: too narrow in the crisis, too wide after it", digits = 1)

#| **The audit strip.** One cell per forecast. A filled green cell means the truth landed inside the 80% interval; a red cell means it fell outside. Look for clusters: misses come in bunches, not at random.
h1 <- audit[audit$h == 1, ]; h12 <- audit[audit$h == 12, ]
viz_custom("ch10-strip", title = "80% intervals for retail sales: misses come in clusters", nominal = 80,
           rows = list(list(name = "1 month ahead", date = ts_dates(ts(h1$time, start = h1$time[1], frequency = 12)), inside = h1$in80),
                       list(name = "12 months ahead", date = ts_dates(ts(h12$time, start = h12$time[1], frequency = 12)), inside = h12$in80)),
           source = .course_src())
