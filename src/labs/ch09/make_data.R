# Generates src/components/ch09/var_extra.json for two Chapter 9 explorables:
#   IrfReader   (impulse responses to a funds-rate shock, incl. the cumulated price-level response)
#   LagWobble   (VAR(1)..VAR(8): unemployment-equation coefficients on the funds rate vs. the IRF)
# Same data, sample and vars functions as the chapter's labs. Run from site/public:
#   cd site/public && Rscript ../src/labs/ch09/make_data.R
source("r/course.R")
suppressMessages({ library(vars); library(jsonlite) })
q <- function(id) fred(id, to = "quarter")
y <- na.omit(ts.intersect(400 * diff(log(q("CPIAUCSL"))), q("UNRATE"), q("FEDFUNDS")))
y <- window(y, start = c(1960, 1), end = c(2000, 4))
colnames(y) <- c("infl", "unemp", "ffr")
H <- 20; RUNS <- 300
r4 <- function(x) round(as.numeric(x), 4)
band <- function(b, res) list(pt = r4(b$irf$ffr[, res]), lo = r4(b$Lower$ffr[, res]), hi = r4(b$Upper$ffr[, res]))

# ── IrfReader: baseline VAR(4), funds-rate shock, levels and cumulated responses ──
m <- VAR(y, p = 4, type = "const")
set.seed(2001)
b  <- irf(m, impulse = "ffr", n.ahead = H, ortho = TRUE, boot = TRUE, runs = RUNS, ci = 0.90)
set.seed(2001)
bc <- irf(m, impulse = "ffr", n.ahead = H, ortho = TRUE, boot = TRUE, runs = RUNS, ci = 0.90, cumulative = TRUE)
# cumulated inflation response / 4 = % change in the CPI level (inflation is 400 x quarterly log change)
price <- list(pt = r4(bc$irf$ffr[, "infl"] / 4), lo = r4(bc$Lower$ffr[, "infl"] / 4), hi = r4(bc$Upper$ffr[, "infl"] / 4))
reader <- list(shock_sd = r4(b$irf$ffr[1, "ffr"]),
               infl = band(b, "infl"), unemp = band(b, "unemp"), ffr = band(b, "ffr"), price = price)

# ── LagWobble: the same question with 1 to 8 lags ──
sel <- VARselect(y, lag.max = 8, type = "const")
lags <- list()
for (p in 1:8) {
  mp <- VAR(y, p = p, type = "const")
  cf <- coef(mp)$unemp                                   # unemployment equation: Estimate, Std. Error, t, p
  rows <- paste0("ffr.l", 1:p)
  set.seed(2001)
  bp <- irf(mp, impulse = "ffr", response = "unemp", n.ahead = H, ortho = TRUE, boot = TRUE, runs = 200, ci = 0.90)
  gp <- causality(mp, cause = "ffr")$Granger$p.value
  # joint test inside the unemployment equation only: do the p funds-rate lags matter together?
  e <- mp$varresult$unemp
  r <- lm(update(formula(e), paste(". ~ . -", paste(rows, collapse = " - "))), data = e$model)
  ft <- anova(r, e)
  lags[[p]] <- list(p = p, n = mp$obs,
                    est = r4(cf[rows, 1]), se = r4(cf[rows, 2]), pval = r4(cf[rows, 4]),
                    sum = r4(sum(cf[rows, 1])),
                    joint_p = signif(ft$`Pr(>F)`[2], 4),
                    aic = round(sel$criteria["AIC(n)", p], 4), bic = round(sel$criteria["SC(n)", p], 4),
                    root = r4(max(roots(mp))),
                    irf = list(pt = r4(bp$irf$ffr[, "unemp"]), lo = r4(bp$Lower$ffr[, "unemp"]), hi = r4(bp$Upper$ffr[, "unemp"])))
  cat("p =", p, "done\n")
}
out <- list(meta = list(sample = "1960Q1-2000Q4", h = H, runs = RUNS, ci = 0.90,
                        select = as.list(sel$selection)), reader = reader, lags = lags)
write_json(out, "../src/components/ch09/var_extra.json", auto_unbox = TRUE, digits = NA)
cat("wrote var_extra.json\n")
