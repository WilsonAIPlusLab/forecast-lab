#| **Two series that have nothing to do with each other.** Food prices (CPI food, index 1982–84 = 100, SA) and e-commerce sales ($ millions, SA), monthly, 2000 to 2019. We stop before 2020 so the pandemic does not drive the story. Both trend up for twenty years, for completely different reasons.
food <- fred("CPIUFDSL", start = c(2000, 1), end = c(2019, 12))       # CPI food price index, 1982-84 = 100
ecom <- fred("MRTSSM4541USS", start = c(2000, 1), end = c(2019, 12))  # online retail sales, $ millions
lev  <- lm(log(food) ~ log(ecom))            # regression in levels (logs)
summary(lev)$r.squared                       # share of variation "explained": suspiciously close to 1

#| **The same regression on growth rates.** `diff(log(x))` is the monthly change in logs, and multiplying by 100 makes it (almost exactly) a percent change. Once the shared upward trend is removed, the "relationship" vanishes. The levels regression was measuring two trends, not a link.
g_food <- 100 * diff(log(food))              # monthly food inflation, % (not annualized)
g_ecom <- 100 * diff(log(ecom))              # monthly e-commerce growth, %
grw <- lm(g_food ~ g_ecom)                   # regression in growth rates
# R-squared and the slope's t-statistic, levels vs growth rates
round(rbind(levels = c(R2 = summary(lev)$r.squared, t_slope = coef(summary(lev))[2, "t value"]),
            growth = c(R2 = summary(grw)$r.squared, t_slope = coef(summary(grw))[2, "t value"])), 3)
viz_scatter(as.numeric(g_ecom), as.numeric(g_food), xlab = "e-commerce growth, % per month",
            ylab = "food inflation, % per month",
            title = "In growth rates, the two series are unrelated")

#| **Log + difference = growth rate.** For core PCE in September 2026, compare the exact percent change with 100 times the log difference. They agree to two decimals, because $\ln(1+g) \approx g$ when $g$ is small. Over 12 months the log changes simply **add up**, which is why we model inflation as a log difference.
p  <- fred("PCEPILFE", start = c(2024, 1))   # recent core PCE data
n  <- length(p)                              # position of the latest month (September 2026)
c(pct_change = 100 * (p[n] / p[n - 1] - 1),  # exact % change from the month before
  log_diff   = 100 * (log(p[n]) - log(p[n - 1])),   # log difference x 100: nearly identical
  annualized = 1200 * (log(p[n]) - log(p[n - 1])))  # x 12 more: "% per year" pace, comparable with the 2% target
# 12-month inflation two ways: the sum of 12 monthly log changes, then converted back to a % change
sum12 <- sum(diff(log(p))[(n - 12):(n - 1)])        # last 12 monthly log changes (diff() is one shorter than p)
c(sum_of_12_log_changes = 100 * sum12, yoy_pct = 100 * (exp(sum12) - 1), check = 100 * (p[n] / p[n - 12] - 1))

#| **Seasonal difference of a log = year-over-year growth.** Retail sales are *not* seasonally adjusted, so December towers over other months. `diff(x, lag = 12)` subtracts the same month a year earlier: the seasonal pattern cancels, and what is left is (almost exactly) the 12-month growth rate.
rs  <- fred("RSXFSN", start = 2010, end = c(2019, 12))   # retail sales, $ millions, NSA
d12 <- 100 * diff(log(rs), lag = 12)                     # seasonal log difference, x 100
yoy <- 100 * (rs / stats::lag(rs, -12) - 1)              # exact YoY % change; lag(rs, -12) = value 12 months earlier
viz_ts(`Seasonal log difference x 100` = d12, `YoY % change` = yoy, ylab = "%",
       title = "A seasonal difference of logs is the year-over-year growth rate")

#| **How many differences? Look at the spread and the lag-1 autocorrelation.** For the unemployment rate (1990–2019) we compare d = 0, 1 and 2. A rule of thumb from Robert Nau (Duke): the right d usually has the **smallest standard deviation**, and a lag-1 autocorrelation of **−0.5 or below** warns that you went one difference too far.
library(forecast)                            # ndiffs()
u <- fred("UNRATE", start = 1990, end = c(2019, 12))   # unemployment rate, %, SA
cand <- list(`d = 0` = u, `d = 1` = diff(u), `d = 2` = diff(u, differences = 2))   # 0, 1 and 2 differences
# for each candidate: standard deviation and lag-1 autocorrelation ($acf[2] is lag 1)
tab <- t(sapply(cand, function(x) c(sd = sd(x), lag1_acf = acf(x, lag.max = 1, plot = FALSE)$acf[2])))
viz_table(as.data.frame(tab), digits = 3, highlight = "sd",
          title = "One difference is enough: d = 2 has a larger spread and a lag-1 ACF of -0.57")
ndiffs(u)                                    # the KPSS-based count agrees: 1
