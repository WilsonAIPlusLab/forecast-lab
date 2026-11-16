# Hidden check (not shown to students): refits the levels model and confirms both blanks.
.m <- xgb.train(params = list(eta = 0.1, max_depth = 2, tree_method = "exact", nthread = 1),
                data = xgb.DMatrix(as.matrix(tr[, lev]), label = tr$sales / 1000), nrounds = 143)
.p <- predict(.m, xgb.DMatrix(as.matrix(te[, lev]))); .cap <- max(tr$sales) / 1000
.ok_fit <- exists("pred_lev") && length(pred_lev) == nrow(te) && max(abs(pred_lev - .p)) < 1e-3
check_that(.ok_fit && exists("ceiling_bn") && abs(ceiling_bn - .cap) < 1e-6,
  sprintf("No forecast tops $%.1fbn: the highest is $%.1fbn, below the training record of $%.1fbn, while actual sales reached $%.1fbn. Trees answer with values built from months they have seen, so a levels model hits a ceiling near its training record, and its MAE ($%.1fbn) is more than double the growth model's ($10.35bn). Predict growth, then convert back: last month x (1 + growth/100).",
          .cap, max(.p), .cap, max(te$sales) / 1000, mean(abs(te$sales / 1000 - .p))),
  if (.ok_fit) "The model is right. For the ceiling, take the largest value of tr$sales and convert $ millions to $ billions (divide by 1,000)." else
    "The label must be the training sales in $ billions: tr$sales divided by 1,000. (Use tr, the training rows, not te.)")
