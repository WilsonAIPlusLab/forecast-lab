.sa <- exp(log(retail) - stl(log(retail), s.window = 13, robust = TRUE)$time.series[, "seasonal"])
.w <- window(.sa, start = c(2025, 11), end = c(2025, 12))
.g <- 100 * (.w[2] / .w[1] - 1)
.o <- window(fred("RSAFS", quiet = TRUE) - fred("RSFSDP", quiet = TRUE), start = c(2025, 11), end = c(2025, 12)); .og <- 100 * (.o[2] / .o[1] - 1)
.raw <- window(retail, start = c(2025, 11), end = c(2025, 12)); .rg <- 100 * (.raw[2] / .raw[1] - 1)
check_that(exists("growth") && is.numeric(growth) && length(growth) == 1 && abs(growth - .g) < 1e-6,
  sprintf("Adjusted growth = %.1f%%, against a raw jump of %.1f%%. Almost all of December's leap was just December. Census's official X-13 figure for the same month is %+.1f%%: it also removes trading-day and holiday effects that STL ignores. Verdict: a solid, ordinary December, not a boom.", .g, .rg, .og),
  "Two checks: (1) seasonal adjustment subtracts the seasonal component, so the first blank is `seasonal`; (2) growth is new / old - 1, and December is the second element, `last2[2]`.")
