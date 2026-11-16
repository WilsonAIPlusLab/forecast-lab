# Hidden setup shared by the Chapter 12 labs: builds the supervised feature table.
# (Lab 12.1 builds the same table step by step, with explanations.)
# Creates: retail, d (every month), train (1993-2022), test (2023 onward), features (7 predictor names), make_features().
library(xgboost)
lag_by <- function(x, k) c(rep(NA, k), head(x, -k))
weekend_days <- function(dates) {     # dates = first day of each month
  n_days <- as.integer(format(as.Date(format(dates + 31, "%Y-%m-01")) - 1, "%d"))
  first  <- as.integer(format(dates, "%u"))                       # 1 = Monday ... 7 = Sunday
  wday   <- outer(first - 1, 0:30, "+") %% 7 + 1
  rowSums(wday >= 6 & outer(n_days, 1:31, ">="))
}
read_monthly <- function(id) {          # keeps the date next to every value, so gaps stay gaps
  d <- read.csv(file.path("data", paste0(id, ".csv")), na.strings = c(".", ""))
  data.frame(date = as.Date(d[[1]]), value = d[[2]])
}
sent  <- read_monthly("UMCSENT"); unemp <- read_monthly("UNRATE")
cal   <- seq(as.Date("1948-01-01"), as.Date(format(max(sent$date, unemp$date) + 31, "%Y-%m-01")), by = "month")
macro <- data.frame(date = cal, sent_lm   = lag_by(sent$value[match(cal, sent$date)], 1),
                                unrate_lm = lag_by(unemp$value[match(cal, unemp$date)], 1))
make_features <- function(y, extra_month = FALSE) {
  if (extra_month) y <- ts(c(y, NA), start = start(y), frequency = 12)
  d <- data.frame(date = as.Date(ts_dates(y)), sales = as.numeric(y))
  d$lag1      <- lag_by(d$sales, 1)
  d$growth    <- 100 * (d$sales / d$lag1 - 1)
  d$month     <- as.integer(format(d$date, "%m"))
  d$growth_ly <- lag_by(d$growth, 12)
  d$growth_lm <- lag_by(d$growth, 1)
  d$yoy_lm    <- 100 * (d$lag1 / lag_by(d$sales, 13) - 1)
  d$weekend   <- weekend_days(d$date)
  d <- merge(d, macro, all.x = TRUE)
  d[!is.na(d$growth_ly) & !is.na(d$yoy_lm), ]
}
features <- c("month", "growth_ly", "growth_lm", "yoy_lm", "weekend", "sent_lm", "unrate_lm")
retail <- fred("RSXFSN", start = 1992)
d      <- make_features(retail)
train  <- d[d$date <= as.Date("2022-12-01"), ]
test   <- d[d$date >= as.Date("2023-01-01"), ]
