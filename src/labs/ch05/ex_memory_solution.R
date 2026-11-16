library(forecast)                                # for ets()
online <- fred("MRTSSM4541USN", start = 2015)    # U.S. e-commerce sales, $ millions, NSA
train  <- window(online, end = c(2025, 8))       # same training data as the ETS lab
fit    <- ets(train)                             # ets() picks ETS(M,A,M), as in the lab

# 1. The level's smoothing parameter
alpha <- fit$par[["alpha"]]                      # [[ ]] returns the bare number, without its name

# 2. Its half-life: months until a new observation's weight falls by half
half_life <- log(0.5) / log(1 - alpha)           # weight after j months is alpha * (1 - alpha)^j

# 3. The slope at the end of the sample, in $ millions per month
st    <- fit$states                              # one row per month; the last row is August 2025
slope <- st[nrow(st), "b"]                       # "b" = slope state; nrow(st) = last row

# avg_age = 1 / alpha: how old the level's information is, on average, in months
round(c(alpha = alpha, half_life = half_life, avg_age = 1 / alpha, slope = unname(slope)), 3)
