library(forecast)
y <- fred("MRTSSM445USN", start = 2010) / 1000   # grocery (food & beverage store) sales, $ billions per month, NOT seasonally adjusted
h <- 12
origins <- seq(length(y) - 48, length(y) - 4, by = 4)   # 12 forecast origins over the last four years

# The method: ETS(M,Ad,M), re-estimated from scratch every time it is called
fit_fc <- function(x) forecast(ets(x, model = "MAM", damped = TRUE), h = h)$mean

# 1. Rolling-origin errors: at each origin, fit on the data up to that origin only
errs <- t(sapply(origins, function(o) y[o + 1:h] - as.numeric(fit_fc(window(y, end = time(y)[o])))))
mae1 <- mean(abs(errs[, 1]), na.rm = TRUE)                 # typical miss, 1 month ahead
q <- quantile(errs[, h], c(0.10, 0.90), na.rm = TRUE)      # errors at the 12-month horizon

# 2. Final forecast from all the data, with the 80% range from past errors
fc <- fit_fc(y)
point <- fc[h]
lo80 <- point + q[1]
hi80 <- point + q[2]

# 3. Generate the summary: the last %.1f slot is the typical one-month-ahead miss
when <- format(as.Date(ts_dates(fc)[h]), "%B %Y")
summary_text <- sprintf(
  "We expect U.S. grocery store sales (not seasonally adjusted) to be about $%.1f billion in %s (80%% range $%.1f to $%.1f billion). Over 12 forecast origins in the past four years, the model's typical one-month-ahead miss was $%.1f billion.",
  point, when, lo80, hi80, mae1)
cat(strwrap(summary_text, 90), sep = "\n")
