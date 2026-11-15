#| **Fit the logit on every month whose answer is known:** January 1959 to October 2025. October 2025 is the last month whose 12-month-ahead outcome (October 2026) is in the data.
logit <- glm(rec_ahead ~ spread, data = known, family = binomial(link = "logit"))
coef(logit)

#| **Predict every month, including the last 12.** Those final rows have no answer yet: they are genuine forecasts. `type = "response"` gives probabilities.
d$p <- predict(logit, newdata = d, type = "response")
tail(d[, c("date", "spread", "p")], 3)

#| **Date each probability at the month it is about.** A forecast made in October 2026 is about October 2027. Shifting the dates forward 12 months lines each probability up with the recession it is trying to predict, so the grey bars and the peaks should coincide. This is how the New York Fed draws its chart.
prob <- ts(d$p, start = c(1960, 1), frequency = 12)
viz_ts(`P(recession)` = prob, recessions = TRUE, ylab = "probability",
       title = "The yield-curve model's recession probability, dated at the month it forecasts",
       subtitle = "Logit on the 10y minus 3m spread 12 months earlier; grey = NBER recession")

#| **Compare with the New York Fed's published model.** The NY Fed uses a *probit* estimated on 1959–2009 data and publishes the coefficients: intercept -0.5333, slope -0.6330. It also converts the bill rate to a bond-equivalent yield, so its spread differs slightly from ours. Apply its coefficients to our spread.
d$p_nyfed <- pnorm(-0.5333 - 0.6330 * d$spread)
round(100 * tail(d[, c("p", "p_nyfed")], 1), 1)

#| **The 2022–24 episode.** The curve stayed inverted from November 2022 to November 2024. Find the highest probability the model reached and the month it was about.
recent <- d[d$date >= as.Date("2022-01-01"), ]
peak <- recent[which.max(recent$p), ]
c(made_in = format(peak$date, "%b %Y"), about = format(seq(peak$date, by = "12 months", length.out = 2)[2], "%b %Y"), prob = round(peak$p, 3))

#| **Today's reading as a headline.**
last <- tail(d, 1)
viz_kpi(`Spread, Oct 2026 (pct. points)` = round(last$spread, 2),
        `P(recession in Oct 2027), our logit` = paste0(round(100 * last$p, 1), "%"),
        `Same, NY Fed coefficients` = paste0(round(100 * last$p_nyfed, 1), "%"),
        title = "The yield curve's latest recession signal")
