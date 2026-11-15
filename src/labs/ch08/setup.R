# Hidden setup shared by the Chapter 8 labs: rebuilds the data frame `d` from the first lab.
rec    <- fred("USREC", start = 1959)
spread <- fred("GS10", start = 1959) - fred("TB3MS", start = 1959)
X <- ts.intersect(rec, spread)
d <- data.frame(date = as.Date(ts_dates(X)), spread = as.numeric(X[, "spread"]), rec = as.numeric(X[, "rec"]))
d$rec_ahead <- c(d$rec[-(1:12)], rep(NA, 12))
known <- d[!is.na(d$rec_ahead), ]
