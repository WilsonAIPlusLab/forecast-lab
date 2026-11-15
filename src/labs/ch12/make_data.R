# Generates the precomputed data behind the Chapter 12 explorables (not a student lab).
# Run from the site folder:  "/c/Program Files/R/R-4.4.3/bin/Rscript.exe" src/labs/ch12/make_data.R
# Writes src/components/ch12/shap_data.json and src/components/ch12/global_local.json.
# Models and settings are exactly those of Labs 12.3 (SHAP) and 12.4 (global vs local), so the numbers match.
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

# ── 2. Global vs local across history lengths (Lab 12.4) ───────────────────
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
setwd(site)
cat("wrote", file.path(out_dir, c("shap_data.json", "global_local.json")), "\n")
