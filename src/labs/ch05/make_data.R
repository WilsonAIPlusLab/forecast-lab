# Generates src/components/ch05/etsdata.json for two of the chapter's explorables:
#  - "states": the month-by-month level, slope and seasonal states of the ETS model ets() picks
#    for e-commerce (ETS(M,A,M)) and total retail (ETS(A,A,A)), the same fits as the ETS lab;
#  - "ladder": the AICc of every default ETS candidate, with its parameters, for four data sets.
# Run from site/:  Rscript src/labs/ch05/make_data.R
library(forecast); library(jsonlite)
setwd("public"); source("r/course.R")
r4 <- function(x, d = 4) round(x, d)
split <- function(id, start) {                     # same split as the labs: train to Aug 2025, test = next 12 months
  y <- fred(id, start = start, quiet = TRUE)
  list(train = window(y, end = c(2025, 8)), test = window(y, start = c(2025, 9)))
}

# ---- states: what the chosen model "believes" before each month, and the forecast it implies
states_of <- function(id, start, label) {
  d <- split(id, start); fit <- ets(d$train)
  st <- fit$states; n <- length(d$train)
  mult <- substr(fit$components[3], 1, 1) == "M"  # multiplicative season?
  l <- st[1:n, "l"]; b <- st[1:n, "b"]; s <- st[1:n, "s12"]   # state BEFORE month t (row t), s12 = index used for month t
  fitted <- as.numeric(fitted(fit))
  # future: h-step forecasts from the final state (point forecasts of forecast())
  fc <- forecast(fit, h = 12)
  L <- st[n + 1, "l"]; B <- st[n + 1, "b"]; S <- rev(st[n + 1, paste0("s", 1:12)])  # S[1] = oldest = next month's index
  list(id = id, label = label, method = fit$method, mult = mult,
       par = as.list(r4(fit$par[intersect(c("alpha", "beta", "gamma", "phi"), names(fit$par))])),
       sigma = r4(sqrt(fit$sigma2), 5),
       date = ts_dates(d$train), y = as.numeric(d$train), l = r4(l, 1), b = r4(b, 2), s = r4(s, 4),
       fitted = r4(fitted, 1),
       fdate = ts_dates(fc$mean), fmean = r4(as.numeric(fc$mean), 1), factual = as.numeric(d$test),
       L = r4(L, 1), B = r4(B, 2), S = r4(as.numeric(S), 4))
}

# ---- ladder: every default candidate, its AICc and parameters
cands <- list(ANN = c("ANN", FALSE), AAN = c("AAN", FALSE), AAdN = c("AAN", TRUE), ANA = c("ANA", FALSE),
              AAA = c("AAA", FALSE), AAdA = c("AAA", TRUE), MNN = c("MNN", FALSE), MAN = c("MAN", FALSE),
              MAdN = c("MAN", TRUE), MNA = c("MNA", FALSE), MAA = c("MAA", FALSE), MAdA = c("MAA", TRUE),
              MNM = c("MNM", FALSE), MAM = c("MAM", FALSE), MAdM = c("MAM", TRUE))
ladder_of <- function(id, start, label, note) {
  d <- split(id, start); auto <- ets(d$train)
  rows <- lapply(names(cands), function(k) {
    f <- tryCatch(ets(d$train, model = cands[[k]][1], damped = as.logical(cands[[k]][2])), error = function(e) NULL)
    if (is.null(f)) return(NULL)
    p <- f$par
    list(code = k, method = f$method, aicc = r4(f$aicc, 2), k = length(p) + 1,   # + 1 for the error variance
         alpha = r4(p[["alpha"]]), beta = if ("beta" %in% names(p)) r4(p[["beta"]]) else NULL,
         gamma = if ("gamma" %in% names(p)) r4(p[["gamma"]]) else NULL, phi = if ("phi" %in% names(p)) r4(p[["phi"]]) else NULL,
         sigma = r4(sqrt(f$sigma2), 5), mae = r4(accuracy(forecast(f, h = 12), d$test)["Test set", "MAE"], 1))
  })
  list(id = id, label = label, note = note, start = start, auto = auto$method, n = length(d$train),
       rows = Filter(Negate(is.null), rows))
}

out <- list(
  states = list(
    states_of("MRTSSM4541USN", 2015, "E-commerce"),
    states_of("RSXFSN", 2015, "Total retail")),
  ladder = list(
    ladder_of("MRTSSM4541USN", 2015, "E-commerce", "U.S. e-commerce sales, $ millions, NSA, Jan 2015 to Aug 2025"),
    ladder_of("RSXFSN", 2015, "Total retail", "U.S. retail sales excluding food services, $ millions, NSA, Jan 2015 to Aug 2025"),
    ladder_of("MRTSSM448USN", 2015, "Clothing, from 2015", "Clothing stores, $ millions, NSA, Jan 2015 to Aug 2025 (includes the 2020 collapse)"),
    ladder_of("MRTSSM448USN", 2021, "Clothing, from 2021", "Clothing stores, $ millions, NSA, Jan 2021 to Aug 2025 (starts after the collapse)"))
)
write_json(out, "../src/components/ch05/etsdata.json", auto_unbox = TRUE, digits = NA, null = "null")
cat("wrote etsdata.json\n")
