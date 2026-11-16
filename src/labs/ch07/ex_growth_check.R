# Hidden check for ex_growth: recompute the growth-rate correlations and compare.
.w <- function(x) window(x, start = c(2010, 1), end = c(2019, 12))
.g <- function(x) 100 * diff(log(x))
.j <- .w(fred("PAYEMS")); .c <- .w(fred("ICSA", to = "month")); .p <- .w(fred("CPIAUCSL", quiet = TRUE))
.rg <- c(claims = cor(.g(.c), .g(.j)), cpi = cor(.g(.p), .g(.j)))
.rl <- c(claims = cor(.c, .j), cpi = cor(.p, .j))
.has <- exists("r_growth") && is.numeric(r_growth) && length(r_growth) == 2
.ok <- .has && all(abs(unname(r_growth) - .rg) < 1e-6)
.half <- .has && abs(r_growth[[1]] - .rg[[1]]) < 1e-6
check_that(.ok,
  sprintf("Right. In levels, claims (%.2f) and CPI (%.2f) both look like near-perfect partners for jobs, because all three trended steadily through the 2010s. In monthly growth rates, CPI drops to %.2f (no link) and claims to %.2f: a real but modest link. Your reply: 'The -0.97 measures two trends, not a relationship. In growth rates, claims account for only about %.0f%% of the month-to-month variation in job growth (r squared).'",
          .rl[[1]], .rl[[2]], .rg[[2]], .rg[[1]], 100 * .rg[[1]]^2),
  if (.half) "The claims number is right. For CPI, apply the same growth function g() to cpi."
  else "Check g(): it should be 100 * diff(log(x)), the monthly % change. Levels or plain differences give different numbers.")
