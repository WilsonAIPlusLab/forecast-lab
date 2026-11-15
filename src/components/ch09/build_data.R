# Generates var_data.json for the Chapter 10 explorables. Run from site/public:
#   cd site/public && Rscript ../src/components/ch09/build_data.R
# Everything the explorables show (IRFs, bootstrap bands, FEVD, Granger p-values) comes from here,
# using the same data and the same vars functions as the chapter's labs.
source("r/course.R")
suppressMessages({ library(vars); library(jsonlite) })
set.seed(2001)
q <- function(id) fred(id, to = "quarter")
infl  <- 400 * diff(log(q("CPIAUCSL")))     # CPI inflation, % annualized (quarterly)
unemp <- q("UNRATE")
ffr   <- q("FEDFUNDS")
spread <- q("GS10") - q("TB3MS")
all <- na.omit(ts.intersect(infl, unemp, ffr, spread))
colnames(all) <- c("infl", "unemp", "ffr", "spread")
y <- window(all[, 1:3], start = c(1960, 1), end = c(2000, 4))
P <- 4; H <- 20; RUNS <- 300

perms <- list(c("infl","unemp","ffr"), c("infl","ffr","unemp"), c("unemp","infl","ffr"),
              c("unemp","ffr","infl"), c("ffr","infl","unemp"), c("ffr","unemp","infl"))
r3 <- function(x) round(as.numeric(x), 4)
irfs <- list(); fevds <- list()
for (o in perms) {
  key <- paste(o, collapse = ",")
  m <- VAR(y[, o], p = P, type = "const")
  b <- irf(m, n.ahead = H, ortho = TRUE, boot = TRUE, runs = RUNS, ci = 0.90)
  irfs[[key]] <- lapply(setNames(o, o), function(imp) lapply(setNames(o, o), function(res)
    list(pt = r3(b$irf[[imp]][, res]), lo = r3(b$Lower[[imp]][, res]), hi = r3(b$Upper[[imp]][, res]))))
  fe <- fevd(m, n.ahead = H)
  fevds[[key]] <- lapply(setNames(o, o), function(res) lapply(setNames(o, o), function(sh) r3(fe[[res]][, sh])))
  cat(key, "done\n")
}
m0 <- VAR(y, p = P, type = "const")
rc <- round(cor(residuals(m0)), 3)
sel <- VARselect(y, lag.max = 8, type = "const")$selection

samples <- list("1960-2000" = c(1960, 1, 2000, 4), "1985-2019" = c(1985, 1, 2019, 4))
gr <- list()
for (sn in names(samples)) {
  s <- samples[[sn]]; ys <- window(all, start = s[1:2], end = s[3:4])
  gr[[sn]] <- list()
  for (p in c(2, 4, 8)) {
    out <- list()
    for (a in colnames(all)) for (bb in colnames(all)) if (a != bb) {
      ct <- causality(VAR(ys[, c(a, bb)], p = p, type = "const"), cause = a)$Granger
      out[[length(out) + 1]] <- list(from = a, to = bb, F = round(as.numeric(ct$statistic), 3), p = signif(as.numeric(ct$p.value), 4))
    }
    gr[[sn]][[as.character(p)]] <- out
  }
}
out <- list(meta = list(sample = "1960Q1-2000Q4", p = P, h = H, runs = RUNS, ci = 0.90, n = nrow(y),
                        select = as.list(sel), resid_cor = rc, vars = colnames(y)),
            irf = irfs, fevd = fevds, granger = gr)
write_json(out, "../src/components/ch09/var_data.json", auto_unbox = TRUE, digits = NA)
cat("wrote var_data.json\n")
