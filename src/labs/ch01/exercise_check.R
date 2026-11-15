.cpi <- ts(read.csv("data/CPIAUCSL.csv")$CPIAUCSL, start = c(1947, 1), frequency = 12)
.infl <- 100 * (.cpi / stats::lag(.cpi, -12) - 1)
.k <- max(which(!is.na(.infl)))
.truth <- .infl[.k]
.when <- format(as.Date(ts_dates(.infl)[.k]), "%B %Y")
.f <- fred("CPIAUCSL", quiet = TRUE)
.fi <- 100 * (.f / stats::lag(.f, -12) - 1)
.fwhen <- format(as.Date(tail(ts_dates(.fi), 1)), "%B %Y")
.extra <- if (.fwhen != .when) sprintf(" If you had loaded CPI with fred(), which fills October 2025 by interpolation, you would also get %.1f%% for %s, but that number divides by an estimated base month, not a published one. BLS itself does not publish 12-month changes for October 2026 for that reason.", tail(.fi, 1), .fwhen) else ""
.fail <- if (exists("latest") && is.numeric(latest) && length(latest) == 1 && isTRUE(latest < 0))
  "Your inflation is negative, so the lag points the wrong way. stats::lag(cpi, 12) moves the series 12 months earlier, so you divided by next year's prices. Use -12 to get the value from a year ago." else
  "Two blanks: a monthly series has frequency 12, and the year-ago value is stats::lag(cpi, -12) (minus means 'from the past')."
check_that(exists("latest") && is.numeric(latest) && length(latest) == 1 && abs(latest - .truth) < 1e-8,
  paste0(sprintf("CPI inflation was %.1f%% in %s, the latest month you can compute from published data. The next month is NA because its year-ago value falls on October 2025, which BLS never published after the 2025 shutdown.", .truth, .when),
         .extra, " (BLS headlines quote the not seasonally adjusted index, so its 12-month figures can differ slightly from this SA calculation.)"),
  .fail)
