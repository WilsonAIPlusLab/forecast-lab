# Hidden check (not shown to students): refits the forest without month and compares importances.
set.seed(1); .m <- randomForest(g ~ g1 + g2 + g12, data = train, ntree = 300, mtry = 2, importance = TRUE)
.imp <- imp_pct(.m)
check_that(exists("imp_small") && identical(sort(names(imp_small)), c("g1", "g12", "g2")) && isTRUE(all.equal(unname(imp_small["g12"]), unname(.imp["g12"]))),
  sprintf("Right. Without month, the seasonal lag's importance jumps from %d%% to %d%%, while the test MAE rises only a little (%.2f vs %.2f points). Month and g12 carry the same seasonal information, so with both in the model each one can stand in for the other and the credit is split. Importance tells you how much this fitted model leans on a feature, not how much the feature matters in the world. Drop both, and the MAE nearly doubles (about 3.55).", imp_full[["g12"]], .imp[["g12"]], mae(rf_full), mae(.m)),
  "Not yet. Blank 1 is the seasonal lag (growth in the same month last year), so the formula reads g ~ g1 + g2 + g12. Blank 2 is the smaller forest you just fitted, rf_small.")
