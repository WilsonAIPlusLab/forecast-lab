# Hidden grader: rebuilds the growth-rate panel, standardizes it, and compares the PCA results.
.g <- lapply(ids, function(id) 100 * diff(log(fred(id, start = 2009, quiet = TRUE))))
.p <- window(do.call(cbind, .g), start = c(2010, 1), end = c(2019, 12)); colnames(.p) <- ids
.s <- prcomp(scale(.p))$sdev^2; .s <- .s / sum(.s)
.raw <- prcomp(.p); .rs <- .raw$sdev^2 / sum(.raw$sdev^2)
.ok_panel <- exists("panel") && NROW(panel) == NROW(.p) && max(abs(as.numeric(panel) - as.numeric(.p))) < 1e-8
.ok_share <- exists("share") && length(share) == 5 && abs(share[1] - .s[1]) < 1e-6
check_that(.ok_panel && .ok_share,
  sprintf("Right: component 1 explains %.1f%% of the variance, and all five series load positively. Two lessons for free. Skip scale() and PC 1 'explains' %.0f%%, but it is almost only vehicle unit sales (loading %.2f), the noisiest series. Use log levels instead of growth rates and PC 1 explains about 95%%: that is a shared upward trend, not a shared cycle.",
          100 * .s[1], 100 * .rs[1], abs(.raw$rotation["TOTALSA", 1])),
  if (!.ok_panel) "Step 1: growth = 100 * diff(log(x)). diff() takes month-to-month changes of the log." else
    "Step 2: standardize with scale(panel) before prcomp(), so every series is in standard-deviation units.")
