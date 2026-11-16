# Generates src/components/ch00/ch00data.json for the chapter's explorables.
# Run from site/:  Rscript src/labs/ch00/make_data.R
# The "now" forecast is exactly the model of first.R (auto.arima on log retail sales from 2012).
# The "time machine" refits the same recipe at earlier forecast origins and keeps what really happened.
library(forecast)
library(jsonlite)
setwd("public")
source("r/course.R")                                  # gives fred()
r0 <- function(x) round(as.numeric(x))                # $ millions, whole numbers
ym <- function(x) sprintf("%d-%02d-01", floor(time(x) + 1e-6), cycle(x))   # ts -> "YYYY-MM-01"

retail <- fred("RSXFSN", start = 2012, quiet = TRUE)  # same data as first.R

pack <- function(fc) list(                             # one forecast object -> plain lists
  date = ym(fc$mean), mean = r0(fc$mean),
  lo80 = r0(fc$lower[, "80%"]), hi80 = r0(fc$upper[, "80%"]),
  lo95 = r0(fc$lower[, "95%"]), hi95 = r0(fc$upper[, "95%"]))

# ---- 1. today's forecast (same as the first lab)
fit <- auto.arima(retail, lambda = 0)
now <- pack(forecast(fit, h = 24))
now$model <- paste(capture.output(print(fit))[2], collapse = "")
cat("now:", now$model, "\n")

# ---- 2. time machine: stand at the end of an earlier year, forecast 24 months, compare with reality
origins <- c(2016, 2017, 2018, 2019, 2021, 2022, 2023)
past <- lapply(origins, function(o) {
  train <- window(retail, end = c(o, 12))             # data available at the end of year o
  f <- auto.arima(train, lambda = 0)
  fc <- forecast(f, h = 24)
  out <- pack(fc)
  act <- window(retail, start = c(o + 1, 1), end = c(o + 2, 12))   # what really happened
  out$actual <- r0(act)
  out$origin <- o
  out$model <- capture.output(print(f))[2]
  in80 <- sum(act >= fc$lower[, "80%"] & act <= fc$upper[, "80%"])
  in95 <- sum(act >= fc$lower[, "95%"] & act <= fc$upper[, "95%"])
  mape <- mean(abs(act - fc$mean) / act) * 100
  cat(sprintf("origin Dec %d: %s | inside 80%%: %d/24, inside 95%%: %d/24, avg miss %.1f%%\n",
              o, out$model, in80, in95, mape))
  out
})

out <- list(
  history = list(date = ym(retail), value = r0(retail)),
  now = now,
  past = past
)
write_json(out, "../src/components/ch00/ch00data.json", auto_unbox = TRUE, digits = NA)
cat("wrote ch00data.json\n")
