#| **Packages and data.** `dynlm` lets you write lags inside a regression formula with `L()`. `lmtest` and `sandwich` give robust standard errors. We model the **monthly change in payrolls** (thousands of jobs) and the **monthly % change in claims**.
library(dynlm); library(lmtest); library(sandwich); library(forecast)   # lag formulas; tests; robust s.e.; ARIMA
claims <- fred("ICSA", to = "month")    # initial claims, monthly average, SA
jobs   <- fred("PAYEMS")                # nonfarm payrolls, thousands, SA
dj  <- diff(jobs)                       # jobs added this month, thousands
dcl <- 100 * diff(log(claims))          # % change in claims from last month

#| **Start with the naive version: a static regression.** Same-month claims only, no lags, 1990 to 2019. Then look at the residuals: `bgtest()` is the Breusch–Godfrey test for autocorrelation. A tiny p-value says this month's error predicts next month's, which breaks the OLS assumption behind the standard errors.
static <- dynlm(dj ~ dcl, start = c(1990, 1), end = c(2019, 12))   # OLS of jobs added on same-month claims growth
bgtest(static, order = 12)              # test for autocorrelation in residuals up to lag 12
round(acf(resid(static), plot = FALSE)$acf[2:4], 2)   # residual autocorrelation at lags 1-3

#| **Same coefficient, honest standard error.** `coeftest()` with `vcov = NeweyWest(...)` keeps the OLS estimate but replaces its standard error with one that allows for autocorrelation (Newey–West, 1987). We use 6 lags, close to the rule of thumb 0.75·n^(1/3) for n = 360. Compare the `dcl` rows: the standard error nearly doubles and the t-statistic roughly halves.
coeftest(static)                        # ordinary OLS standard errors
coeftest(static, vcov = NeweyWest(static, lag = 6, prewhite = FALSE))   # autocorrelation-robust (HAC) standard errors

#| **A better model: autoregressive distributed lag, ADL(2, 3).** `L(dj, 1:2)` adds jobs added one and two months ago; `L(dcl, 0:3)` adds claims growth this month and up to three months ago. Now the dynamics live in the model instead of in the errors. (Claims for month *t* are published weekly, before the jobs report for month *t*, so lag 0 is fair for a *nowcast*. For a true forecast you need lag 1 and beyond; see the last lab.)
adl <- dynlm(dj ~ L(dj, 1:2) + L(dcl, 0:3), start = c(1990, 1), end = c(2019, 12))   # 2 own lags + claims lags 0-3
coeftest(adl, vcov = NeweyWest(adl, lag = 6, prewhite = FALSE))   # coefficients with robust standard errors
bgtest(adl, order = 12)$p.value         # is any autocorrelation left in the residuals?

#| **Short-run and long-run multipliers.** The coefficient on `dcl` at lag 0 is the **impact multiplier**: the jobs change in the same month. Feeding a one-time 1% rise in claims through the model month by month gives the **dynamic multipliers**. Their sum, Σβ / (1 − Σφ), is the **long-run multiplier**: the total effect on the *level* of employment if claims stay 1% higher.
b    <- coef(adl)                       # order: intercept, dj lags 1-2, dcl lags 0-3
phi  <- b[2:3]; beta <- b[4:7]          # phi = own-lag (AR) coefficients; beta = claims coefficients
H    <- 24; irf <- numeric(H + 1)       # trace the response for 24 months; irf[1] is month 0
for (h in 0:H) {                        # month h response = direct claims effect + echo of earlier responses
  irf[h + 1] <- (if (h <= 3) beta[h + 1] else 0) +
                (if (h >= 1) phi[1] * irf[h] else 0) + (if (h >= 2) phi[2] * irf[h - 1] else 0)
}
long_run <- sum(beta) / (1 - sum(phi))  # total effect of a permanent 1% rise in claims
# [[1]] extracts a plain number; sum(irf[1:13]) = cumulative effect over months 0-12
round(c(impact = beta[[1]], after_12_months = sum(irf[1:13]), long_run = long_run), 1)

#| **Draw the response to a 10% jump in claims.** Bars: jobs added each month relative to normal. Line: the running total, the effect on the level of employment. Notice how the autoregressive terms make a short shock echo for many months.
viz_custom("ch07-multipliers", h = 0:H, value = 10 * irf, cumulative = cumsum(10 * irf),   # scale 1% effects to a 10% jump
           ylab = "thousands of jobs", title = "A 10% jump in claims costs jobs for months, not just once",
           source = "FRED (ICSA, PAYEMS); ADL(2,3), 1990–2019")

#| **Third option: regression with ARIMA errors.** `auto.arima(y, xreg = x)` fits y = a + b·x + error, where the error follows an ARIMA model chosen by AICc. The slope gets its own standard error from a model that respects the autocorrelation. Compare the `xreg` estimate with the static OLS one above.
y <- window(dj,  start = c(1990, 1), end = c(2019, 12))   # window() trims a ts to 1990-2019
x <- window(dcl, start = c(1990, 1), end = c(2019, 12))
arx <- auto.arima(y, xreg = x, seasonal = FALSE)          # regression on x with ARIMA errors
arx                                                       # the "xreg" row is the slope on claims growth
