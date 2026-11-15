#| **Same vehicle-sales data**, plus the 10-year Treasury yield, a fifth candidate driver that moves almost one-for-one with mortgage rates.
library(forecast)
veh <- fred("TOTALSA"); gas <- fred("GASREGW", to = "month"); mr <- fred("MORTGAGE30US", to = "month")
g10 <- fred("GS10")
un  <- fred("UNRATE")
d <- window(ts.intersect(veh, gas, un, mr, g10), start = c(1993, 1))
chip <- ts(as.numeric(floor(time(d)) %in% 2021:2022), start = start(d), frequency = 12)
d <- cbind(d, chip); colnames(d) <- c("veh", "gas", "un", "mr", "g10", "chip")
df <- data.frame(d, trend = seq_len(nrow(d)))

#| **Six candidate models**, from one driver to everything. A fair comparison needs the same sample for all of them. `trend` is just 1, 2, 3, … counting months.
specs <- list(`un`                         = veh ~ un,
              `gas + un`                   = veh ~ gas + un,
              `gas + un + mr`              = veh ~ gas + un + mr,
              `gas + un + mr + chip`       = veh ~ gas + un + mr + chip,
              `+ 10-yr yield`              = veh ~ gas + un + mr + chip + g10,
              `+ 10-yr yield + trend`      = veh ~ gas + un + mr + chip + g10 + trend)
fits <- lapply(specs, function(f) lm(f, data = df))

#| **`CV()` scores each model five ways.** `CV` is leave-one-out cross-validated MSE; `AIC`, `AICc` and `BIC` reward fit but charge a price for every extra coefficient (BIC charges the most); `AdjR2` is R² with a penalty. Lower is better for the first four, higher for AdjR2.
tab <- t(sapply(fits, CV))
round(tab, 3)

#| **Add the honest test: a time split.** Leave-one-out CV mixes past and future, so we also refit each model on data through 2023 and score its *ex-post* forecasts for 2024 onward. Remember from the previous lab that ex-post is the best case: the drivers are known exactly.
yr <- floor(time(d))[as.integer(rownames(df))]
train <- df[yr <= 2023, ]; test <- df[yr >= 2024, ]
test_rmse <- sapply(specs, function(f) {
  p <- predict(lm(f, data = train), newdata = test)
  sqrt(mean((test$veh - p)^2))
})
tab <- cbind(tab[, c("CV", "AIC", "BIC", "AdjR2")], `Test RMSE` = test_rmse)
viz_table(tab, highlight = c("CV", "AIC", "BIC", "Test RMSE"), digits = 3,
          title = "In-sample criteria and the 2024-26 test do not always agree")

#| **Multicollinearity check.** The variance inflation factor (VIF) for a driver is 1 / (1 − R²) from regressing that driver on all the others. Above about 10 is a warning sign. We compute it by hand here; `car::vif()` gives the same numbers.
vif <- function(m) { X <- model.matrix(m)[, -1]
  sapply(colnames(X), function(j) 1 / (1 - summary(lm(X[, j] ~ X[, colnames(X) != j]))$r.squared)) }
round(vif(fits[["+ 10-yr yield"]]), 1)

#| **What collinearity does, and does not, do.** Adding the 10-year yield doubles the mortgage-rate slope and gives the yield the "wrong" sign, because the model cannot tell two near-identical drivers apart. Yet the fitted values barely change. Collinearity wrecks *interpretation*, not *prediction*.
rbind(`without 10-yr` = coef(fits[["gas + un + mr + chip"]])[c("mr")],
      `with 10-yr`    = coef(fits[["+ 10-yr yield"]])[c("mr")])
coef(fits[["+ 10-yr yield"]])["g10"]
cor(fitted(fits[["gas + un + mr + chip"]]), fitted(fits[["+ 10-yr yield"]]))
