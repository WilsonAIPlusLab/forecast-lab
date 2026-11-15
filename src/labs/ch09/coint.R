#| **Two interest rates, 1960–2019, monthly.** The 10-year Treasury yield (`GS10`) and the 3-month Treasury bill rate (`TB3MS`), both in percent. Each wanders for decades: up to the early 1980s, then down for 40 years. We stop in 2019 to keep the zero-rate years 2020–21 and the 2022 hikes out of a light first pass.
library(urca)
g10 <- fred("GS10",  start = c(1960, 1), end = c(2019, 12))
tb  <- fred("TB3MS", start = c(1960, 1), end = c(2019, 12))
viz_ts(`10-year` = g10, `3-month` = tb, Spread = g10 - tb, recessions = TRUE, ylab = "%",
       title = "Each yield wanders; the gap between them keeps snapping back")

#| **Step 0: is each series a random walk?** The augmented Dickey–Fuller test (`ur.df`, with a constant: `type = "drift"`) has the null *"unit root"*. The test statistic `tau2` must be **below** the 5% critical value of −2.86 to reject. Neither yield gets close, so treat each as nonstationary, I(1).
c(GS10 = ur.df(g10, type = "drift", lags = 4)@teststat[1],
  TB3MS = ur.df(tb, type = "drift", lags = 4)@teststat[1])

#| **Engle–Granger, step 1: the long-run regression.** Regress one yield on the other. If they are cointegrated, this regression is "superconsistent" and estimates the leash: GS10 ≈ 2.23 + 0.84 × TB3MS. (Its t-statistics are meaningless here, so ignore them.)
eg <- lm(g10 ~ tb)
coef(eg)

#| **Engle–Granger, step 2: are the residuals stationary?** Run an ADF test on the residuals (no constant: they already have mean zero). **Careful:** because β was *estimated*, the critical values are not the usual ones. With two variables, the 5% Engle–Granger critical value is about −3.34 (MacKinnon 2010), not the −1.95 that `ur.df` prints. Our −3.81 still rejects: the yields are cointegrated.
z <- ts(residuals(eg), start = start(g10), frequency = 12)
ur.df(z, type = "none", lags = 4)@teststat[1]

#| **Johansen's test** (`ca.jo`) does it in one system and can find more than one cointegrating relation when there are more than two series. `type = "trace"` tests *r = 0* (no cointegration) and then *r ≤ 1*. Read it from the bottom row up: 31.5 beats even the 1% critical value for *r = 0*, but 2.6 is far below the 10% value for *r ≤ 1*. Conclusion: exactly **one** cointegrating relation.
jo <- ca.jo(cbind(GS10 = g10, TB3MS = tb), type = "trace", ecdet = "const", K = 4, spec = "transitory")
cbind(stat = round(jo@teststat, 2), jo@cval)

#| **The VECM, in light form.** `cajorls()` estimates the vector error-correction model with r = 1. `beta` is the leash: GS10 − 0.99 × TB3MS − 1.51, so the long-run spread is about 1.5 points with a slope near 1 (the expectations theory of the term structure predicts exactly 1). The `ect1` row holds the **adjustment speeds**: when the spread is above normal, next month the 10-year falls and the 3-month rises, each by about 2.5% of the gap.
vecm <- cajorls(jo, r = 1)
round(vecm$beta, 3)
round(coef(vecm$rlm)["ect1", ], 4)
