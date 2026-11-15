#| **Read the weekly claims with their real dates.** Initial jobless claims (`ICSA`, seasonally adjusted) are published every Thursday for the week ending the previous Saturday. We read the CSV directly so each row keeps its exact week-ending date; we need those dates to know which weeks belong to which month. Look at the last rows: this is the **ragged edge**, the newest data that exist today.
claims <- read.csv("data/ICSA.csv")
claims$date  <- as.Date(claims$observation_date)
claims$k     <- claims$ICSA / 1000                     # thousands of claims
claims$month <- format(claims$date, "%Y-%m")
tail(claims[, c("date", "k", "month")], 4)

#| **Aggregate weekly to monthly** (the "bridge" from high to low frequency). We average the weeks whose week-ending date falls in each month, and count how many weeks we have. The latest month has only one week so far: its average is a *partial* aggregate, and it will change as more Thursdays arrive.
cl <- aggregate(k ~ month, data = claims, FUN = mean)
cl$weeks <- aggregate(k ~ month, data = claims, FUN = length)$k
tail(cl, 3)

#| **Line up the monthly target.** The target is the monthly change in nonfarm payrolls (`PAYEMS`, thousands of jobs, SA). The predictors are the change in average claims from last month (`dcl`) and last month's payroll change (`dp_lag`). Payrolls for October 2026 are the latest available; November is still unknown.
pay <- fred("PAYEMS", start = 1989)
d <- data.frame(month = substr(ts_dates(pay), 1, 7), dp = c(NA, diff(as.numeric(pay))))
d$dp_lag <- c(NA, head(d$dp, -1))
d$cl  <- cl$k[match(d$month, cl$month)]
d$dcl <- d$cl - c(NA, head(d$cl, -1))
d$yr  <- as.numeric(substr(d$month, 1, 4))
tail(d, 3)

#| **Fit the bridge equation**, skipping 2020–2021: COVID moved payrolls by millions in a month and would swamp everything else in least squares. The claims coefficient says: each extra 1,000 claims per week (on average, versus last month) goes with roughly 3,000 fewer jobs. Compare the residual standard error with the AR-only model: claims shave only a little off the typical miss.
est <- subset(d, yr >= 1990 & !(yr %in% 2020:2021) & !is.na(dcl) & !is.na(dp_lag))
bridge <- lm(dp ~ dp_lag + dcl, data = est)
ar     <- lm(dp ~ dp_lag, data = est)
round(coef(bridge), 2)
c(bridge_sigma = summary(bridge)$sigma, ar_sigma = summary(ar)$sigma)

#| **Nowcast November 2026 from one week of claims.** We plug in October's payroll change and the partial-month claims change. The 90% prediction interval is wide: about ±200,000 jobs. One week of claims cannot pin down a jobs report. The interval also assumes the remaining weeks look like the first, which is part of the honest uncertainty.
now <- data.frame(dp_lag = tail(d$dp, 1), dcl = tail(cl$k, 1) - cl$k[nrow(cl) - 1])
nowcast <- predict(bridge, now, interval = "prediction", level = 0.90)
round(nowcast)

#| **Was the bridge actually useful? Test it the honest way.** For every month we re-fit both models using only earlier data, then nowcast that month. In the calm 2023–2026 period, claims add almost nothing. In the 2008–09 recession they help clearly, because layoffs show up in claims weeks before the jobs report. Nowcasting pays off most at turning points, exactly when it matters.
oos <- function(m_from, m_to) {
  rows <- which(d$month >= m_from & d$month <= m_to)
  t(sapply(rows, function(i) {
    tr <- subset(d[1:(i - 1), ], yr >= 1990 & !(yr %in% 2020:2021) & !is.na(dcl) & !is.na(dp_lag))
    c(actual = d$dp[i], AR = unname(predict(lm(dp ~ dp_lag, tr), d[i, ])),
      Bridge = unname(predict(lm(dp ~ dp_lag + dcl, tr), d[i, ])))
  }))
}
calm <- oos("2023-01", "2026-10"); gfc <- oos("2008-01", "2009-12")
mae <- function(r) colMeans(abs(r[, "actual"] - r[, c("AR", "Bridge")]))
score <- cbind(`2023-2026 (calm)` = mae(calm), `2008-2009 (recession)` = mae(gfc))
score
viz_table(score, highlight = colnames(score), digits = 0,
          title = "Claims help most in a downturn: nowcast MAE, thousands of jobs")
