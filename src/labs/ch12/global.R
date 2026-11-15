#| **Stack 14 retail and food-service categories into one long table.** Each category is a separate Census series (NSA, $ millions): motor vehicles, furniture, gas stations, e-commerce, restaurants and bars, and so on. `make_features()` (from the hidden setup) builds the same seven features for each one, and `cat` records which category a row belongs to, as a number from 1 to 14. Trees split that number into ranges, which is crude, but two splits are enough to isolate any single category. Because the target is *growth in %*, a $10bn category and a $150bn category sit happily in the same model.
# category name = Census code; the FRED id is "MRTSSM" + code + "USN"
cats <- c(`Motor vehicles` = "441", Furniture = "442", Electronics = "443", `Building materials` = "444",
          `Food & beverage stores` = "445", `Health & personal care` = "446", `Gas stations` = "447",
          Clothing = "448", `Sporting goods & hobby` = "451", `General merchandise` = "452",
          `Misc. stores` = "453", Nonstore = "454", `E-commerce` = "4541", `Food services & bars` = "722")
# build one feature table per category, tag it with its number and name, then stack them (rbind)
panel <- do.call(rbind, lapply(seq_along(cats), function(i) {
  p <- make_features(fred(paste0("MRTSSM", cats[i], "USN"))); p$cat <- i; p$name <- names(cats)[i]; p }))
table(panel$date >= as.Date("2023-01-01"))    # count rows: FALSE = before 2023, TRUE = test period

#| **Choose how much history each model gets.** `years = 3` means training on 2019–2021 and validating on 2022. Three years is 36 rows per category, the situation of a new product or a new store. Change it to `29` later to use all the history (that run takes roughly 20 seconds in the browser).
years <- 3                                    # years of training history per category
fit_rows <- panel[panel$date >= as.Date(sprintf("%d-01-01", 2022 - years)) & panel$date <= as.Date("2021-12-01"), ]   # fit block
val_rows <- panel[format(panel$date, "%Y") == "2022", ]   # validation block: 2022
test_rows <- panel[panel$date >= as.Date("2023-01-01"), ]   # test block: 2023 onward

#| **One helper trains a model the honest way**: early stopping on 2022 picks the number of trees, then we refit on fit + validation rows with that many trees.
params <- list(eta = 0.1, max_depth = 3, tree_method = "exact", nthread = 1)
# a = fit rows, b = validation rows, cols = feature names
boost_es <- function(a, b, cols) {
  M <- function(z) xgb.DMatrix(as.matrix(z[, cols]), label = z$growth)   # rows -> XGBoost's data format
  m <- xgb.train(params = params, data = M(a), nrounds = 500, evals = list(valid = M(b)), early_stopping_rounds = 30, verbose = 0)
  xgb.train(params = params, data = M(rbind(a, b)), nrounds = attributes(m)$early_stop$best_iteration)   # refit on a + b
}

#| **Global vs local.** The *global* model is one model trained on all 14 categories at once, with `cat` as an extra feature. The *local* approach trains 14 separate models, one per category. Same features, same settings; the only difference is who learns from whom.
global <- boost_es(fit_rows, val_rows, c(features, "cat"))   # one model for all categories
test_rows$g_global <- predict(global, xgb.DMatrix(as.matrix(test_rows[, c(features, "cat")])))   # its growth forecasts
for (i in seq_along(cats)) {                  # one local model per category
  local <- boost_es(fit_rows[fit_rows$cat == i, ], val_rows[val_rows$cat == i, ], features)   # only category i's rows
  test_rows$g_local[test_rows$cat == i] <- predict(local, xgb.DMatrix(as.matrix(test_rows[test_rows$cat == i, features])))
}

#| **Score each category in dollars.** Convert predicted growth back to sales, then compute MAPE (mean absolute percentage error) per category over the 44 test months (January 2023 to August 2026).
ape <- function(g) 100 * abs(test_rows$sales - test_rows$lag1 * (1 + g / 100)) / test_rows$sales   # absolute % error per row
# aggregate(... ~ name, FUN = mean): average both error columns within each category
res <- aggregate(cbind(Local = ape(test_rows$g_local), Global = ape(test_rows$g_global)) ~ name, data = test_rows, FUN = mean)
res$`Gain from global (pts)` <- res$Local - res$Global   # positive = global model is better
res$Winner <- ifelse(res$Global < res$Local, "Global", "Local")
res <- res[order(res$Global - res$Local), ]   # biggest global gains first
c(global_wins = sum(res$Winner == "Global"), avg_local = mean(res$Local), avg_global = mean(res$Global))

#| **The verdict.** With three years of history per category, one shared model beats 14 separate ones in 9 of 14 categories and cuts the average MAPE from about 5.4% to 4.1%: each category borrows patterns (December peaks, the 2020 shock) from the others. Now set `years <- 29` and run again: with three decades of data each, the advantage disappears (average MAPE 2.90% local vs 3.00% global). Cross-learning pays most when each series is short.
names(res)[1] <- "Category"                   # rename the first column for display
viz_kpi(`Average MAPE, local models` = sprintf("%.2f%%", mean(res$Local)), `Average MAPE, global model` = sprintf("%.2f%%", mean(res$Global)),
        `Categories where global wins` = sprintf("%d of 14", sum(res$Winner == "Global")))   # headline numbers
viz_table(res, digits = 2,
          title = sprintf("With %d years of history, the global model wins %d of 14 categories", years, sum(res$Winner == "Global")))
