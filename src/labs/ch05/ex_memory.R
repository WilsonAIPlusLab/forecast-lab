library(forecast)                                # for ets()
online <- fred("MRTSSM4541USN", start = 2015)    # U.S. e-commerce sales, $ millions, NSA
train  <- window(online, end = c(2025, 8))       # same training data as the ETS lab
fit    <- ets(train)                             # ets() picks ETS(M,A,M), as in the lab

# 1. The level's smoothing parameter
# blank: pull the element named "alpha" out of the fitted parameters fit$par
alpha <- fit$par[["______"]]

# 2. Its half-life: months until a new observation's weight falls by half
# blank: the same formula as the explorer, log(0.5) / log(1 - something)
half_life <- log(0.5) / log(1 - ______)

# 3. The slope at the end of the sample, in $ millions per month
# blank: the column of fit$states that holds the slope (the level is "l")
st    <- fit$states                              # one row per month; the last row is August 2025
slope <- st[nrow(st), "______"]

round(c(alpha = alpha, half_life = half_life, avg_age = 1 / alpha, slope = unname(slope)), 3)
