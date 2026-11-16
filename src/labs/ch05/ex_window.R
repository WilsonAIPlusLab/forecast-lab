library(forecast)                                # for ets(), forecast(), accuracy()
food <- fred("MRTSSM722USN", start = 2015)       # food services & drinking places, $ millions, NSA
test <- window(food, start = c(2025, 9))         # the same 12 test months for both options

# Option A: every month since 2015, including the 2020 lockdown collapse
long <- window(food, end = c(2025, 8))
# Option B: start after the collapse
# blank: the first year of the shorter window (January of the year after 2020)
short <- window(food, start = c(______, 1), end = c(2025, 8))

fit_long  <- ets(long)                           # ets() chooses a model for each window
fit_short <- ets(short)
fc_long   <- forecast(fit_long,  h = 12)         # forecast the 12 test months
# blank: the horizon, so the forecast covers the whole test period
fc_short  <- forecast(fit_short, h = ______)

# Compare in dollars on the same months. (Not MASE: its yardstick is computed from each training window.)
# blank: the name of accuracy()'s mean-absolute-error column
mae <- c(long  = accuracy(fc_long,  test)["Test set", "______"],
         short = accuracy(fc_short, test)["Test set", "MAE"])
round(mae)                                       # $ millions per month
round(c(long = fit_long$par[["alpha"]], short = fit_short$par[["alpha"]]), 2)   # how jumpy each level is
