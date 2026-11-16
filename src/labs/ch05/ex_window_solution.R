library(forecast)                                # for ets(), forecast(), accuracy()
food <- fred("MRTSSM722USN", start = 2015)       # food services & drinking places, $ millions, NSA
test <- window(food, start = c(2025, 9))         # the same 12 test months for both options

# Option A: every month since 2015, including the 2020 lockdown collapse
long <- window(food, end = c(2025, 8))
# Option B: start in January 2021, after the collapse
short <- window(food, start = c(2021, 1), end = c(2025, 8))

fit_long  <- ets(long)                           # ets() chooses a model for each window
fit_short <- ets(short)
fc_long   <- forecast(fit_long,  h = 12)         # forecast the 12 test months
fc_short  <- forecast(fit_short, h = length(test))   # length(test) = 12 months

# Compare in dollars on the same months. (Not MASE: its yardstick is computed from each training window.)
mae <- c(long  = accuracy(fc_long,  test)["Test set", "MAE"],
         short = accuracy(fc_short, test)["Test set", "MAE"])
round(mae)                                       # $ millions per month
round(c(long = fit_long$par[["alpha"]], short = fit_short$par[["alpha"]]), 2)   # how jumpy each level is
