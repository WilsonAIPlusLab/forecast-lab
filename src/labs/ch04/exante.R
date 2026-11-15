#| **Same data as the first lab.** Vehicle sales and three drivers, monthly, 1993 onward, plus the chip-shortage dummy.
library(forecast)
veh <- fred("TOTALSA"); gas <- fred("GASREGW", to = "month"); mr <- fred("MORTGAGE30US", to = "month")
un  <- fred("UNRATE")
d <- window(ts.intersect(veh, gas, un, mr), start = c(1993, 1))
chip <- ts(as.numeric(floor(time(d)) %in% 2021:2022), start = start(d), frequency = 12)
d <- cbind(d, chip); colnames(d) <- c("veh", "gas", "un", "mr", "chip")

#| **Stand at the end of 2023.** Fit the regression only on data through December 2023. Everything after is the test period.
train <- window(d, end = c(2023, 12))
test  <- window(d, start = c(2024, 1))
h <- nrow(test)
fit <- lm(veh ~ gas + un + mr + chip, data = train)

#| **Ex-post forecast: cheating on the drivers.** Plug in the drivers' *actual* future values. Nobody could do this in December 2023, because nobody knew 2025's gas prices yet. Ex-post forecasts are useful for one thing: checking whether the *relationship* held up.
xpost <- data.frame(test)                      # true future gas, un, mr; chip = 0
f_post <- ts(predict(fit, newdata = xpost), start = c(2024, 1), frequency = 12)

#| **Ex-ante forecast: what you could really have done.** Each driver needs its own forecast. The simplest honest choice is to hold every driver at its December 2023 value (a naive forecast of each driver). This is the number you would have shown your boss.
last <- train[nrow(train), ]
xante <- data.frame(gas = rep(last["gas"], h), un = rep(last["un"], h), mr = rep(last["mr"], h), chip = 0)
f_ante <- ts(predict(fit, newdata = xante), start = c(2024, 1), frequency = 12)

#| **And the benchmark**: the naive forecast of vehicle sales itself (the series is seasonally adjusted, so plain naive is the right yardstick).
f_naive <- naive(train[, "veh"], h = h)
viz_compare(history = window(train[, "veh"], start = 2019), actual = test[, "veh"],
            `Ex-post (true drivers)` = f_post, `Ex-ante (drivers held flat)` = f_ante, Naive = f_naive,
            title = "Knowing the drivers' true future did not make the forecast better")

#| **Score all three** on the test period. Compare the two regression rows: the gap between them is the cost of not knowing the future drivers. Compare both with naive: is the regression adding value at all?
y <- test[, "veh"]; ok <- !is.na(f_post)
sc <- function(f) { e <- (y - f)[ok]; c(ME = mean(e), MAE = mean(abs(e)), RMSE = sqrt(mean(e^2))) }
scores <- rbind(`Ex-post (true drivers)` = sc(f_post), `Ex-ante (drivers held flat)` = sc(f_ante), Naive = sc(f_naive$mean))
viz_table(scores, highlight = c("MAE", "RMSE"), digits = 2, title = "Vehicle sales, test period 2024 onward (millions, SAAR)")
scores
