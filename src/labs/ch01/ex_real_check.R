# Hidden check for ex_real: real gas prices in October-2026 dollars and the month of the real record.
.g <- fred("GASREGW", to = "month", quiet = TRUE); .c <- fred("CPIAUCSL", quiet = TRUE)
.cn <- as.numeric(window(.c, start = c(2026, 10), end = c(2026, 10)))
.rg <- .g * .cn / .c
.pk <- ts_dates(.rg)[which.max(.rg)]
.at <- function(x, y, m) as.numeric(window(x, start = c(y, m), end = c(y, m)))
.v08 <- if (exists("real_gas") && is.ts(real_gas)) tryCatch(.at(real_gas, 2008, 6), error = function(e) NA) else NA
.ok_series <- isTRUE(abs(.v08 - .at(.rg, 2008, 6)) < 1e-6)
.fail <- if (isTRUE(.v08 < .at(.g, 2008, 6)))
  "Your 2008 price got smaller, so you converted the wrong way: multiply by today's CPI (cpi_now) and divide by the CPI of the month itself." else
  if (!.ok_series) "Blank 1: to express a price in October-2026 dollars, multiply by the October 2026 CPI, cpi_now." else
  "Blank 2: which.max() gives the position of the largest value."
check_that(.ok_series && exists("real_peak") && identical(as.character(real_peak), .pk),
  sprintf("Your manager is wrong twice. In sticker prices the record is $%.2f in June 2022, above today's $%.2f. In today's dollars the record is %s at $%.2f a gallon; June 2022's $%.2f is worth $%.2f now. Always say which year's dollars you are quoting.",
          .at(.g, 2022, 6), .at(.g, 2026, 10), format(as.Date(.pk), "%B %Y"), max(.rg), .at(.g, 2022, 6), .at(.rg, 2022, 6)),
  .fail)
