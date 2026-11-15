#| **Pre-COVID retail sales, in logs.** On the log scale, a straight-line trend means a constant *percentage* growth rate, and seasonal effects become percentages too.
library(forecast)
retail <- fred("RSXFSN", start = 2010, end = c(2019, 12))
y <- log(retail)

#| **Detrend by regression.** `tslm()` fits a linear regression to a time series. `trend` is a counter 1, 2, 3, …; `season` adds 11 monthly dummy variables (January is the baseline). One line fits a deterministic trend plus a fixed seasonal pattern.
fit <- tslm(y ~ trend + season)
round(100 * coef(fit)[c("trend", "season2", "season11", "season12")], 2)

#| **Read the coefficients** (multiplied by 100, they are roughly percentages): `trend` is the average growth per month; `season12` is how far a typical December sits above January, the baseline month. Annualize the monthly growth rate to compare it with a familiar number.
round(100 * (exp(12 * coef(fit)["trend"]) - 1), 1)

#| **The second route: differencing.** `diff(y, lag = 12)` subtracts the value 12 months earlier. That kills a fixed seasonal pattern *and* a linear trend in one step, and what is left is year-over-year growth. This is the idea Chapter 6 builds ARIMA models on.
yoy <- diff(y, lag = 12)

#| **Compare what each route leaves behind.** The regression residuals wander slowly above and below zero for years: a straight line cannot follow a trend that bends. The year-over-year series has no seasonal pattern but carries its own slow swings in growth.
viz_ts(`Residual from trend + season regression` = 100 * residuals(fit),
       `Year-over-year growth (12-month difference)` = 100 * yoy,
       facet = TRUE, ylab = "% (log points)",
       title = "Two ways to remove trend and seasonality leave different leftovers")
