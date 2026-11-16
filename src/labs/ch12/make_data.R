# Generates the precomputed data behind the Chapter 12 explorables (not a student lab).
# Run from the site folder:  "/c/Program Files/R/R-4.4.3/bin/Rscript.exe" src/labs/ch12/make_data.R
# Writes src/components/ch12/shap_data.json, global_local.json and interpret_data.json.
# Models and settings are exactly those of Lab 12.3 (SHAP) and the global-vs-local lab, so the numbers match.
# interpret_data.json feeds LevelsVsGrowth (growth vs levels target) and CreditSplit (refits with random
# column sampling). The LearningBudget explorable needs no file: it boosts in the browser with boost.ts.
site <- normalizePath("."); setwd(file.path(site, "public"))
source("r/course.R")
source(file.path(site, "src/labs/ch12/features_setup.R"))
out_dir <- file.path(site, "src/components/ch12")

# ── 1. SHAP values from the tuned model (Lab 12.3) ─────────────────────────
params <- list(eta = 0.1, max_depth = 2, tree_method = "exact", nthread = 1)
fit <- xgb.train(params = params, nrounds = 38, data = xgb.DMatrix(as.matrix(train[, features]), label = train$growth))
full <- d[!is.na(d$growth), ]
fit_all <- xgb.train(params = params, nrounds = 38, data = xgb.DMatrix(as.matrix(full[, features]), label = full$growth))
explain <- function(model, rows) {
  M <- xgb.DMatrix(as.matrix(rows[, features]))
  S <- predict(model, M, predcontrib = TRUE); p <- predict(model, M)
  lapply(seq_len(nrow(rows)), function(i) list(
    date = format(rows$date[i]), lag1 = rows$lag1[i] / 1000, actual = if (is.na(rows$sales[i])) NULL else rows$sales[i] / 1000,
    growth = if (is.na(rows$growth[i])) NULL else rows$growth[i],
    pred = p[i], forecast = rows$lag1[i] * (1 + p[i] / 100) / 1000,
    base = S[i, "(Intercept)"], shap = unname(S[i, features]),
    x = lapply(features, function(f) { v <- rows[i, f]; if (is.na(v)) NULL else v })))
}
nxt <- tail(make_features(retail, extra_month = TRUE), 1)
months <- c(explain(fit, test), lapply(explain(fit_all, nxt), function(m) c(m, list(next_month = TRUE))))
# beeswarm: every month 2005 onward, explained by the model trained through 2022 (percentage points of growth)
bees <- d[d$date >= as.Date("2005-01-01"), ]
Sb <- predict(fit, xgb.DMatrix(as.matrix(bees[, features])), predcontrib = TRUE)
shap_data <- list(
  features = features,
  base = unname(Sb[1, "(Intercept)"]),
  months = months,
  bees = list(date = format(bees$date), test = bees$date >= as.Date("2023-01-01"),
              shap = lapply(features, function(f) round(unname(Sb[, f]), 4)),
              x = lapply(features, function(f) bees[[f]])))
jsonlite::write_json(shap_data, file.path(out_dir, "shap_data.json"), auto_unbox = TRUE, digits = 6, null = "null", na = "null")

# ── 2. Global vs local across history lengths (global-vs-local lab) ───────────────────
cats <- c(`Motor vehicles` = "441", Furniture = "442", Electronics = "443", `Building materials` = "444",
          `Food & beverage stores` = "445", `Health & personal care` = "446", `Gas stations` = "447",
          Clothing = "448", `Sporting goods & hobby` = "451", `General merchandise` = "452",
          `Misc. stores` = "453", Nonstore = "454", `E-commerce` = "4541", `Food services & bars` = "722")
panel <- do.call(rbind, lapply(seq_along(cats), function(i) {
  p <- make_features(fred(paste0("MRTSSM", cats[i], "USN"))); p$cat <- i; p$name <- names(cats)[i]; p }))
gparams <- list(eta = 0.1, max_depth = 3, tree_method = "exact", nthread = 1)
boost_es <- function(a, b, cols) {
  M <- function(z) xgb.DMatrix(as.matrix(z[, cols]), label = z$growth)
  m <- xgb.train(params = gparams, data = M(a), nrounds = 500, evals = list(valid = M(b)), early_stopping_rounds = 30, verbose = 0)
  xgb.train(params = gparams, data = M(rbind(a, b)), nrounds = attributes(m)$early_stop$best_iteration)
}
test_rows <- panel[panel$date >= as.Date("2023-01-01"), ]
val_rows <- panel[format(panel$date, "%Y") == "2022", ]
runs <- lapply(c(2, 3, 5, 8, 12, 29), function(years) {
  fit_rows <- panel[panel$date >= as.Date(sprintf("%d-01-01", 2022 - years)) & panel$date <= as.Date("2021-12-01"), ]
  g <- predict(boost_es(fit_rows, val_rows, c(features, "cat")), xgb.DMatrix(as.matrix(test_rows[, c(features, "cat")])))
  l <- numeric(nrow(test_rows))
  for (i in seq_along(cats)) l[test_rows$cat == i] <- predict(boost_es(fit_rows[fit_rows$cat == i, ], val_rows[val_rows$cat == i, ], features),
                                                              xgb.DMatrix(as.matrix(test_rows[test_rows$cat == i, features])))
  ape <- function(gr) 100 * abs(test_rows$sales - test_rows$lag1 * (1 + gr / 100)) / test_rows$sales
  res <- aggregate(cbind(local = ape(l), global = ape(g)) ~ name, data = test_rows, FUN = mean)
  cat(sprintf("years %2d: local %.3f global %.3f, global wins %d\n", years, mean(res$local), mean(res$global), sum(res$global < res$local)))
  list(years = years, rows_per_series = nrow(fit_rows) / length(cats) + 12, category = res$name, local = res$local, global = res$global)
})
size <- aggregate(sales ~ name, data = test_rows, FUN = mean)
jsonlite::write_json(list(runs = runs, avg_sales_bn = setNames(as.list(size$sales / 1000), size$name), test_from = "2023-01", test_to = format(max(test_rows$date), "%Y-%m")),
                     file.path(out_dir, "global_local.json"), auto_unbox = TRUE, digits = 5)
# ── 3. Growth target (Lab 12.3's tuned model): forecasts and SHAP receipts in $ billions ─────────
# Feeds the LevelsVsGrowth and CreditSplit explorables (interpret_data.json).
P <- list(eta = 0.1, max_depth = 2, tree_method = "exact", nthread = 1)   # the tuned settings of Lab 12.2
DM <- function(df, cols, label = NULL) xgb.DMatrix(as.matrix(df[, cols]), label = label)
fit_g <- xgb.train(params = P, data = DM(train, features, train$growth), nrounds = 38)
Sg <- predict(fit_g, DM(test, features), predcontrib = TRUE)       # % points of growth
pg <- predict(fit_g, DM(test, features))
usd_g <- Sg * test$lag1 / 100 / 1000                                 # same receipt in $ billions

# ── 4. Levels target: the same trees, asked to predict sales in $ billions directly ─────────────
d$sales_ly <- lag_by(d$sales, 12)                                    # sales in the same month last year
lev <- c("month", "lag1", "sales_ly", "weekend", "sent_lm", "unrate_lm")
fit_d <- d[d$date <= as.Date("2021-12-01"), ]; val_d <- d[format(d$date, "%Y") == "2022", ]
es <- xgb.train(params = P, data = DM(fit_d, lev, fit_d$sales / 1000), nrounds = 2000,
                evals = list(valid = DM(val_d, lev, val_d$sales / 1000)), early_stopping_rounds = 50, verbose = 0)
n_lev <- attributes(es)$early_stop$best_iteration                    # trees chosen on 2022, as in Lab 12.1 (143)
tr <- d[d$date <= as.Date("2022-12-01"), ]; te <- d[d$date >= as.Date("2023-01-01"), ]
fit_l <- xgb.train(params = P, data = DM(tr, lev, tr$sales / 1000), nrounds = n_lev)
pl <- predict(fit_l, DM(te, lev)); Sl <- predict(fit_l, DM(te, lev), predcontrib = TRUE)
stopifnot(identical(te$date, test$date))
cat(sprintf("levels: %d trees, base %.1f, MAE %.2f, max fc %.1f, train max %.1f\n", n_lev, Sl[1, "(Intercept)"],
            mean(abs(te$sales / 1000 - pl)), max(pl), max(tr$sales) / 1000))
r1 <- function(v) round(unname(v), 3)
levels_part <- list(
  growth_features = features, level_features = lev, level_trees = n_lev,
  train_max = max(tr$sales) / 1000, train_max_date = format(tr$date[which.max(tr$sales)]),
  train_mean = mean(tr$sales) / 1000,
  months = lapply(seq_len(nrow(test)), function(i) list(
    date = format(test$date[i]), actual = test$sales[i] / 1000, lag1 = test$lag1[i] / 1000,
    sales_ly = te$sales_ly[i] / 1000,
    g_fc = test$lag1[i] * (1 + pg[i] / 100) / 1000, g_base = r1(usd_g[i, "(Intercept)"]), g_shap = r1(usd_g[i, features]),
    g_x = lapply(features, function(f) { v <- test[i, f]; if (is.na(v)) NULL else v }),
    l_fc = pl[i], l_base = r1(Sl[i, "(Intercept)"]), l_shap = r1(Sl[i, lev]))))

# ── 5. Credit split: refits that differ only in random column sampling ──────────────────────────
# colsample_bytree = 0.5: each tree may split only on a random half of the 7 features.
variant <- function(name, cols, p = P, seed = 0) {
  if (seed > 0) { p$colsample_bytree <- 0.5; p$seed <- seed; set.seed(seed) }
  fit <- xgb.train(params = p, data = DM(train, cols, train$growth), nrounds = 38)
  S <- predict(fit, DM(test, cols), predcontrib = TRUE) * test$lag1 / 100 / 1000   # $ billions
  pr <- test$lag1 * (1 + predict(fit, DM(test, cols)) / 100) / 1000
  col <- function(f) if (f %in% cols) r1(S[, f]) else rep(0, nrow(test))
  other <- r1(rowSums(S[, setdiff(cols, c("month", "growth_ly")), drop = FALSE]))
  cat(sprintf("%-28s MAE %.2f  mean|month| %.2f mean|ly| %.2f\n", name, mean(abs(test$sales / 1000 - pr)),
              mean(abs(col("month"))), mean(abs(col("growth_ly")))))
  list(name = name, mae = mean(abs(test$sales / 1000 - pr)), month = col("month"), ly = col("growth_ly"),
       other = other, base = r1(S[, "(Intercept)"]), fc = r1(pr))
}
credit_part <- list(
  dates = format(test$date), actual = test$sales / 1000, lag1 = test$lag1 / 1000,
  variants = list(variant("Tuned model (Lab 12.2)", features),
                  variant("Refit A", features, seed = 1), variant("Refit B", features, seed = 2),
                  variant("Refit C", features, seed = 3), variant("Refit D", features, seed = 4),
                  variant("Without calendar month", setdiff(features, "month"))))
jsonlite::write_json(list(levels = levels_part, credit = credit_part), file.path(out_dir, "interpret_data.json"),
                     auto_unbox = TRUE, digits = 6, null = "null", na = "null")
setwd(site)
cat("wrote", file.path(out_dir, c("shap_data.json", "global_local.json", "interpret_data.json")), "\n")
