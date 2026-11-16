# Hidden check for ex_yoy: the answer must be the December 2025 YoY change of NSA retail sales.
.r <- fred("RSXFSN", quiet = TRUE)
.yoy <- 100 * (.r / stats::lag(.r, -12) - 1); .mom <- 100 * (.r / stats::lag(.r, -1) - 1)
.t <- as.numeric(window(.yoy, start = c(2025, 12), end = c(2025, 12)))
.m <- as.numeric(window(.mom, start = c(2025, 12), end = c(2025, 12)))
.sa <- fred("RSAFS", quiet = TRUE); .samom <- 100 * (.sa / stats::lag(.sa, -1) - 1)
.s <- as.numeric(window(.samom, start = c(2025, 12), end = c(2025, 12)))
.a <- if (exists("answer")) suppressWarnings(as.numeric(answer)) else NA
.fail <- if (length(.a) == 1 && isTRUE(abs(.a - .m) < 1e-6))
  sprintf("That is the month-over-month change (%.1f%%). For data that are not seasonally adjusted it mostly measures the holiday calendar: December beats November every year. Report the change from December 2024 instead.", .m) else
  if (length(.a) == 1 && isTRUE(.a < -5)) "Your YoY number is negative and large: the lag points the wrong way. stats::lag(retail, -12) is the value from 12 months earlier." else
  "Fill the three blanks: the year-ago value is stats::lag(retail, -12), December 2025 is c(2025, 12), and the answer is the YoY number."
check_that(length(.a) == 1 && isTRUE(abs(.a - .t) < 1e-6),
  sprintf("December 2025 sales were %.1f%% above December 2024, a solid but ordinary year. The %.1f%% jump from November is the usual holiday spike (December 2024 jumped %.1f%% too). Cross-check with the seasonally adjusted series (RSAFS, which also includes restaurants): it rose just %.1f%% from November. Hiring for a 12%% boom would have been a mistake.",
          .t, .m, as.numeric(window(.mom, start = c(2024, 12), end = c(2024, 12))), .s),
  .fail)
