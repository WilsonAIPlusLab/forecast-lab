#| **Fit once, then forecast one month at a time.** Train ETS on retail sales 2000–2009 (`RSXFSN`, $ millions, NSA). Then `ets(retail, model = fit, use.initial.values = TRUE)` runs the *same* model, with the same parameters, through all later data. Its fitted values from 2010 on are genuine one-step-ahead forecasts: each uses only data up to the month before.
library(forecast)
retail <- fred("RSXFSN", start = 2000)
fit <- ets(window(retail, end = c(2009, 12)))
onestep <- fitted(ets(retail, model = fit, use.initial.values = TRUE))
fit$method

#| **Nonconformity scores.** For each month, measure how wrong the forecast was, in percent of the forecast: $s_t = |y_t - \hat y_t| / \hat y_t$. Percent errors keep the scores comparable while sales grow from $250 billion to over $600 billion a month.
score <- as.numeric(abs(retail - onestep) / onestep)
when  <- as.numeric(time(retail))

#| **Split conformal, once.** Use the 36 months of 2016–2018 as the **calibration set**. With $n = 36$ scores and $\alpha = 0.2$, take the $\lceil (n+1)(1-\alpha) \rceil$-th smallest score: that is $q$. The 80% conformal interval for any later month is forecast $\times (1 \pm q)$. No normality, no model formula, just the model's own track record.
alpha <- 0.2
cal <- score[when >= 2016 & when < 2019]
n <- length(cal)
q <- sort(cal)[ceiling((n + 1) * (1 - alpha))]
round(c(n = n, q_percent = 100 * q), 2)
viz_custom("ch10-hist", values = 100 * cal, bins = 18, xlab = "calibration error (% of forecast)",
           markers = list(list(x = 100 * q, label = "80% conformal cutoff")),
           title = sprintf("80%% of past misses were smaller than %.1f%%, so the band is ±%.1f%%", 100 * q, 100 * q),
           source = .course_src())

#| **Apply it to 2019.** Twelve new months, each with its band. Count how many land inside.
t19 <- when >= 2019 & when < 2020
in19 <- score[t19] <= q
c(inside = sum(in19), months = sum(t19))

#| **Make it rolling.** Time series drift, so a calibration set from years ago grows stale. A common fix: every month, recalibrate on the **last 36** errors. Compare with the model's own formula interval, which uses the $\sigma$ estimated on 2000–2009: forecast $\times (1 \pm z\,\sigma)$ for this multiplicative-error model.
K <- 36; z <- qnorm(1 - alpha / 2); sig <- sqrt(fit$sigma2)
idx <- which(when >= 2013)
conf_in <- sapply(idx, function(i) score[i] <= sort(score[(i - K):(i - 1)])[ceiling((K + 1) * (1 - alpha))])
form_in <- score[idx] <= z * sig
era <- cut(when[idx], c(0, 2020, 2022, 3000), right = FALSE, labels = c("2013–2019", "2020–2021", "2022–2026"))
tab <- rbind(`Model formula` = c(All = mean(form_in), tapply(form_in, era, mean)),
             `Rolling conformal` = c(All = mean(conf_in), tapply(conf_in, era, mean)))
round(100 * tab, 1)
viz_table(100 * tab, digits = 1, title = "80% intervals, actual coverage (%): conformal is closer to 80 overall and far closer in the crisis")

#| **See where each method missed.** Red cells are misses. Both miss every month from March to July 2020: no history could have prepared them. After that, conformal recovers quickly because the shock is now part of its calibration window: it misses only 3 more months through 2021, against 9 for the frozen formula. The price: conformal bands stay wide while 2020 sits in the 36-month window, so it over-covers in 2022 and early 2023, then tightens again.
d <- ts_dates(ts(when[idx], start = when[idx[1]], frequency = 12))
viz_custom("ch10-strip", title = "Rolling conformal recovers after shocks; the frozen formula does not", nominal = 80,
           rows = list(list(name = "Model formula", date = d, inside = form_in),
                       list(name = "Rolling conformal", date = d, inside = conf_in)),
           source = .course_src())
