#| **Fit once, then forecast one month at a time.** Train ETS on retail sales 2000–2009 (`RSXFSN`, $ millions, NSA). Then `ets(retail, model = fit, use.initial.values = TRUE)` runs the *same* model, with the same parameters, through all later data. Its fitted values from 2010 on are genuine one-step-ahead forecasts: each uses only data up to the month before.
library(forecast)                             # ets() and fitted()
retail <- fred("RSXFSN", start = 2000)        # monthly U.S. retail sales, $ millions, not seasonally adjusted
fit <- ets(window(retail, end = c(2009, 12))) # estimate ETS on 2000-2009 only
# same fixed model run through all data: one-step forecasts
onestep <- fitted(ets(retail, model = fit, use.initial.values = TRUE))
fit$method                                    # which ETS model was chosen

#| **Nonconformity scores.** For each month, measure how wrong the forecast was, in percent of the forecast: $s_t = |y_t - \hat y_t| / \hat y_t$. Percent errors keep the scores comparable while sales grow from $250 billion to over $600 billion a month.
score <- as.numeric(abs(retail - onestep) / onestep)   # relative absolute error each month
when  <- as.numeric(time(retail))             # each month's date as a decimal year (2016.0 = Jan 2016)

#| **Split conformal, once.** Use the 36 months of 2016–2018 as the **calibration set**. With $n = 36$ scores and $\alpha = 0.2$, take the $\lceil (n+1)(1-\alpha) \rceil$-th smallest score: that is $q$. The 80% conformal interval for any later month is forecast $\times (1 \pm q)$. No normality, no model formula, just the model's own track record.
alpha <- 0.2                                  # miss rate allowed: 1 - 0.2 = 80% interval
cal <- score[when >= 2016 & when < 2019]      # calibration scores: Jan 2016 to Dec 2018
n <- length(cal)                              # 36 calibration months
q <- sort(cal)[ceiling((n + 1) * (1 - alpha))]   # conformal cutoff: the 30th smallest of 36 scores
round(c(n = n, q_percent = 100 * q), 2)       # q in percent: the band is forecast x (1 +/- q)
# histogram of past misses
viz_custom("ch10-hist", values = 100 * cal, bins = 18, xlab = "calibration error (% of forecast)",
           markers = list(list(x = 100 * q, label = "80% conformal cutoff")),
           # %% prints a literal %
           title = sprintf("80%% of past misses were smaller than %.1f%%, so the band is ±%.1f%%", 100 * q, 100 * q),
           source = .course_src())

#| **Apply it to 2019.** Twelve new months, each with its band. Count how many land inside.
t19 <- when >= 2019 & when < 2020             # TRUE for the 12 months of 2019
in19 <- score[t19] <= q                       # inside the band if the miss is no bigger than q
c(inside = sum(in19), months = sum(t19))      # sum() of TRUE/FALSE counts the TRUEs

#| **Make it rolling.** Time series drift, so a calibration set from years ago grows stale. A common fix: every month, recalibrate on the **last 36** errors. Compare with the model's own formula interval, which uses the $\sigma$ estimated on 2000–2009: forecast $\times (1 \pm z\,\sigma)$ for this multiplicative-error model.
# window length; normal z for 80% (about 1.28); model's sigma
K <- 36; z <- qnorm(1 - alpha / 2); sig <- sqrt(fit$sigma2)
idx <- which(when >= 2013)                    # positions of the months evaluated, 2013 onward
# rolling conformal: cutoff from the previous K scores; TRUE if this month falls inside
conf_in <- sapply(idx, function(i) score[i] <= sort(score[(i - K):(i - 1)])[ceiling((K + 1) * (1 - alpha))])
form_in <- score[idx] <= z * sig              # frozen formula: inside if the miss is within z x sigma
# cut() bins dates into eras; right = FALSE means each bin includes its start year
era <- cut(when[idx], c(0, 2020, 2022, 3000), right = FALSE, labels = c("2013–2019", "2020–2021", "2022–2026"))
# coverage share overall and per era (tapply = mean within each era)
tab <- rbind(`Model formula` = c(All = mean(form_in), tapply(form_in, era, mean)),
             `Rolling conformal` = c(All = mean(conf_in), tapply(conf_in, era, mean)))
round(100 * tab, 1)                           # coverage in %; the promise is 80
viz_table(100 * tab, digits = 1, title = "80% intervals, actual coverage (%): conformal is closer to 80 overall and far closer in the crisis")

#| **See where each method missed.** Red cells are misses. Both miss every month from March to July 2020: no history could have prepared them. After that, conformal recovers quickly because the shock is now part of its calibration window: it misses only 3 more months through 2021, against 9 for the frozen formula. The price: conformal bands stay wide while 2020 sits in the 36-month window, so it over-covers in 2022 and early 2023, then tightens again.
d <- ts_dates(ts(when[idx], start = when[idx[1]], frequency = 12))   # dates of the evaluated months, as text
# one strip row per method
viz_custom("ch10-strip", title = "Rolling conformal recovers after shocks; the frozen formula does not", nominal = 80,
           rows = list(list(name = "Model formula", date = d, inside = form_in),
                       list(name = "Rolling conformal", date = d, inside = conf_in)),
           source = .course_src())
