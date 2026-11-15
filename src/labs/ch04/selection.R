#| **Same vehicle-sales data**, plus the 10-year Treasury yield, a fifth candidate driver that moves almost one-for-one with mortgage rates.
library(forecast)                          # for CV()
# vehicle sales (mn, SAAR), gas ($/gal), 30-year mortgage rate (%); weekly series averaged to months
veh <- fred("TOTALSA"); gas <- fred("GASREGW", to = "month"); mr <- fred("MORTGAGE30US", to = "month")
g10 <- fred("GS10")                        # 10-year Treasury yield, %
un  <- fred("UNRATE")                      # unemployment rate, %
d <- window(ts.intersect(veh, gas, un, mr, g10), start = c(1993, 1))   # months all five share, from Jan 1993
# chip dummy: 1 in 2021-2022 (chip shortage), 0 otherwise
chip <- ts(as.numeric(floor(time(d)) %in% 2021:2022), start = start(d), frequency = 12)
d <- cbind(d, chip); colnames(d) <- c("veh", "gas", "un", "mr", "g10", "chip")
df <- data.frame(d, trend = seq_len(nrow(d)))   # plain data frame plus trend = 1, 2, 3, ...

#| **Six candidate models**, from one driver to everything. A fair comparison needs the same sample for all of them. `trend` is just 1, 2, 3, … counting months.
specs <- list(`un`                         = veh ~ un,   # a named list of formulas
              `gas + un`                   = veh ~ gas + un,
              `gas + un + mr`              = veh ~ gas + un + mr,
              `gas + un + mr + chip`       = veh ~ gas + un + mr + chip,
              `+ 10-yr yield`              = veh ~ gas + un + mr + chip + g10,
              `+ 10-yr yield + trend`      = veh ~ gas + un + mr + chip + g10 + trend)
fits <- lapply(specs, function(f) lm(f, data = df))   # lapply(): fit lm() to each formula, keep the names

#| **`CV()` scores each model five ways.** `CV` is leave-one-out cross-validated MSE; `AIC`, `AICc` and `BIC` reward fit but charge a price for every extra coefficient (BIC charges the most); `AdjR2` is R² with a penalty. Lower is better for the first four, higher for AdjR2.
tab <- t(sapply(fits, CV))                 # sapply() runs CV() on each model; t() puts models in rows
round(tab, 3)

#| **Add the honest test: a time split.** Leave-one-out CV mixes past and future, so we also refit each model on data through 2023 and score its *ex-post* forecasts for 2024 onward. Remember from the previous lab that ex-post is the best case: the drivers are known exactly.
yr <- floor(time(d))[as.integer(rownames(df))]   # calendar year of each row
train <- df[yr <= 2023, ]; test <- df[yr >= 2024, ]   # rows through 2023 to fit; 2024 onward to test
test_rmse <- sapply(specs, function(f) {   # for each formula:
  p <- predict(lm(f, data = train), newdata = test)   # refit on training rows, predict test rows
  sqrt(mean((test$veh - p)^2))             # root mean squared error on the test period
})
tab <- cbind(tab[, c("CV", "AIC", "BIC", "AdjR2")], `Test RMSE` = test_rmse)   # add test RMSE as a column
viz_table(tab, highlight = c("CV", "AIC", "BIC", "Test RMSE"), digits = 3,   # green = best in each column
          title = "In-sample criteria and the 2024-26 test do not always agree")

#| **Multicollinearity check.** The variance inflation factor (VIF) for a driver is 1 / (1 − R²) from regressing that driver on all the others. Above about 10 is a warning sign. We compute it by hand here; `car::vif()` gives the same numbers.
vif <- function(m) { X <- model.matrix(m)[, -1]   # the model's predictor columns, minus the intercept
  # for each driver j: regress it on the other drivers, then VIF = 1 / (1 - R²)
  sapply(colnames(X), function(j) 1 / (1 - summary(lm(X[, j] ~ X[, colnames(X) != j]))$r.squared)) }
round(vif(fits[["+ 10-yr yield"]]), 1)     # [[ ]] picks one model from the list by name

#| **What collinearity does, and does not, do.** Adding the 10-year yield doubles the mortgage-rate slope and gives the yield the "wrong" sign, because the model cannot tell two near-identical drivers apart. Yet the fitted values barely change. Collinearity wrecks *interpretation*, not *prediction*.
rbind(`without 10-yr` = coef(fits[["gas + un + mr + chip"]])[c("mr")],   # mortgage-rate slope, both models
      `with 10-yr`    = coef(fits[["+ 10-yr yield"]])[c("mr")])
coef(fits[["+ 10-yr yield"]])["g10"]       # the 10-year yield's slope
cor(fitted(fits[["gas + un + mr + chip"]]), fitted(fits[["+ 10-yr yield"]]))   # near 1 = same predictions
