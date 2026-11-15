.z <- window(na.omit(ts.intersect(q("GS10") - q("TB3MS"), q("UNRATE"))), start = c(1960, 1), end = c(2000, 4))
colnames(.z) <- c("spread", "unemp")
.p <- VARselect(.z, lag.max = 8, type = "const")$selection[["SC(n)"]]
.truth <- causality(VAR(.z, p = .p, type = "const"), cause = "spread")$Granger$p.value
.late <- {
  .w <- window(na.omit(ts.intersect(q("GS10") - q("TB3MS"), q("UNRATE"))), start = c(1985, 1), end = c(2019, 4))
  colnames(.w) <- c("spread", "unemp")
  causality(VAR(.w, p = VARselect(.w, lag.max = 8, type = "const")$selection[["SC(n)"]], type = "const"), cause = "spread")$Granger$p.value
}
check_that(exists("pval") && is.numeric(pval) && exists("p") && p == .p && abs(pval - .truth) < 1e-8,
  sprintf("BIC picks %d lags and the p-value is %s: in 1960–2000 the slope of the yield curve really did carry information about future unemployment. Now change the window to 1985–2019 (re-select the lags too): the p-value becomes %s. In the recent sample the signal all but disappears in this simple test, so a good forecaster re-tests old relationships instead of trusting them forever.",
          .p, format(signif(.truth, 2)), format(round(.late, 2))),
  "Check the two blanks. The BIC column of VARselect()$selection is named \"SC(n)\" (Schwarz criterion), and the cause must be the spread column, \"spread\". The p-value should come from causality(m, cause = ...)$Granger.")
