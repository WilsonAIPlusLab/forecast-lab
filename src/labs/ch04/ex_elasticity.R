# Your manager asks: "If gas prices rise 20%, by what percent will our sales change,
# holding jobs and interest rates fixed?" Answer with an elasticity.
veh <- fred("TOTALSA"); gas <- fred("GASREGW", to = "month")   # sales (mn, SAAR); gas ($/gal), monthly means
un  <- fred("UNRATE");  mr  <- fred("MORTGAGE30US", to = "month")   # unemployment (%); mortgage rate (%)
d <- window(ts.intersect(veh, gas, un, mr), start = c(1993, 1))   # months all four share, from Jan 1993
chip <- ts(as.numeric(floor(time(d)) %in% 2021:2022), start = start(d), frequency = 12)   # 1 in 2021-22
d <- cbind(d, chip); colnames(d) <- c("veh", "gas", "un", "mr", "chip")

# 1. A log-log model for gas: log sales on log gas (other drivers stay in levels)
# blank: the gas price, transformed so its coefficient is an elasticity
fit_ll <- lm(log(veh) ~ ______ + un + mr + chip, data = d)
b_gas <- unname(coef(fit_ll)[2])           # the gas elasticity (2nd coefficient, after the intercept)
b_gas

# 2. Rule of thumb: % change in sales = elasticity x % change in gas
pct_approx <- b_gas * ______               # blank: the % rise in gas, as a number of percent

# 3. Exact version: sales are multiplied by (new gas / old gas) ^ elasticity
pct_exact <- 100 * (______^b_gas - 1)      # blank: the ratio new price / old price for a 20% rise
c(approx = pct_approx, exact = pct_exact)
