# Hidden check for ex_yoy: recompute both growth rates.
.v <- function(y, m) as.numeric(window(retail, start = c(y, m), end = c(y, m)))
.mom <- 100 * (.v(2025, 12) / .v(2025, 11) - 1); .yoy <- 100 * (.v(2025, 12) / .v(2024, 12) - 1)
check_that(exists("mom") && exists("yoy") && isTRUE(abs(mom - .mom) < 1e-8) && isTRUE(abs(yoy - .yoy) < 1e-8),
  sprintf("Sales rose %.1f%% from November to December, but only %.1f%% from December 2024 to December 2025. The big jump is mostly the holiday season, which happens every year. Comparing a month with the same month a year earlier cancels the seasonal pattern, which is why news reports on unadjusted data often quote year-over-year growth. Chapter 1 shows more ways to transform a series.", .mom, .yoy),
  "Both changes start from December 2025 (dec25). Month over month divides by the month before (nov25); year over year divides by the same month a year earlier (dec24).")
