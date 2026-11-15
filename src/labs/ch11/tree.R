#| **Rebuild the feature table** from the previous lab (retail sales growth, % per month, NSA) and split it by time: train through 2022, test from 2023.
retail <- fred("RSXFSN", start = 2010)
g <- 100 * diff(log(retail))
lag_k <- function(x, k) c(rep(NA, k), head(x, -k))
make_features <- function(g) {
  x <- as.numeric(g)
  data.frame(date = ts_dates(g), g = x, g1 = lag_k(x, 1), g2 = lag_k(x, 2),
             g12 = lag_k(x, 12), month = factor(cycle(g), levels = 1:12))
}
feats <- make_features(g)
train <- na.omit(feats[feats$date <  "2023-01-01", ])
test  <- feats[feats$date >= "2023-01-01", ]

#| **Grow a regression tree with `rpart`.** At each step it tries every feature and every cut point, and keeps the one split that most reduces the **sum of squared errors** (SSE). `maxdepth = 3` stops after three rounds of splits. `cp = 0` and `xval = 0` switch off rpart's own pruning and cross-validation so you see the raw tree.
library(rpart)
fit <- rpart(g ~ g1 + g2 + g12 + month, data = train, method = "anova",
             control = rpart.control(maxdepth = 3, minbucket = 5, cp = 0, xval = 0))
fit

#| **Draw it.** Each box is a group of months; the number is the tree's forecast for that group: the **average growth** of the training months that landed there. Read a path from the top like a set of if-then rules. The first split asks whether growth in the same month last year (`g12`) was below about −15%. Only Januaries are that weak, so the tree has discovered January on its own. Next it separates the strong months (March, May, December) from the rest: seasonality is the biggest signal in an NSA series.
fr <- fit$frame
viz_custom("ch11-tree", title = "Three questions sort every month into one of five forecasts",
           subtitle = "Regression tree for monthly retail sales growth (%), trained 2011–2022",
           nodes = data.frame(id = as.integer(rownames(fr)), var = as.character(fr$var), n = fr$n,
                              yval = round(fr$yval, 2), label = labels(fit, digits = 3, minlength = 0), stringsAsFactors = FALSE))

#| **Predictions are piecewise constant.** A tree can only output one of its leaf averages, so its forecasts form a staircase: here, just five distinct values (one per leaf). `unique()` shows them. Every test-month forecast is one of these numbers.
pred_test <- predict(fit, test)
sort(unique(round(pred_test, 2)))

#| **How deep should the tree be?** Grow trees of depth 1 to 10 (now allowing leaves as small as 2 months) and record the error on training data and on the 2023+ test months (RMSE, in percentage points of growth). Training error always falls as the tree grows. Test error bottoms out at depth 5 (about 2.4 percentage points) and then creeps back up: the extra splits memorize noise.
rmse <- function(a, f) sqrt(mean((a - f)^2))
depths <- 1:10
err <- t(sapply(depths, function(d) {
  m <- rpart(g ~ g1 + g2 + g12 + month, data = train, method = "anova",
             control = rpart.control(maxdepth = d, minbucket = 2, cp = 0, xval = 0))
  c(train = rmse(train$g, predict(m, train)), test = rmse(test$g, predict(m, test)))
}))
round(err, 2)

#| **Plot the two error curves.** The gap between them is **overfitting**. Professional tools pick the depth (or rpart's complexity parameter `cp`) by cross-validation instead of by eye.
viz_lines(depths, Training = err[, "train"], Test = err[, "test"], xlab = "tree depth",
          ylab = "RMSE (pp of monthly growth)", zero = TRUE,
          title = "Deeper trees fit the past better, not the future")
