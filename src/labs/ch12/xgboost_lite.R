# Browser fallback for Chapter 13 (hidden setup; not shown to students).
# xgboost's compiled code cannot yet load in webR (WebAssembly link error: it needs shared memory).
# When the real package is unavailable, this attaches a small pure-R re-implementation of the parts of
# the xgboost API the labs use, as "package:xgboost", so `library(xgboost)` and the lab code run unchanged.
# Algorithm = XGBoost's exact greedy method (tree_method = "exact") for reg:squarederror:
#   gradient g = pred - y, hessian h = 1; leaf weight = -G/(H + lambda) * eta;
#   split gain = 1/2 [GL^2/(HL+lambda) + GR^2/(HR+lambda) - G^2/(H+lambda)] - gamma; midpoint thresholds;
#   learned default direction for missing values; base score = mean label (one Newton step, as in xgboost >= 2).
# SHAP values (predcontrib = TRUE) are exact path-dependent Shapley values (cover-weighted), the quantity
# TreeSHAP computes. Natively it reproduces CRAN xgboost 3.x results (tree_method = "exact", subsample = 1).
# Everything runs inside local() so helper objects do not leak into the student's workspace.
local({
  # Only act in the browser (webR = "emscripten"), and only if the real package is missing.
  if (!identical(R.version$os, "emscripten") || "package:xgboost" %in% search()) return(invisible())
  if (isTRUE(tryCatch(suppressWarnings(suppressMessages(requireNamespace("xgboost", quietly = TRUE))), error = function(e) FALSE))) return(invisible())
  x <- new.env()                                  # the functions to attach as "package:xgboost"

  # xgb.DMatrix(): stores the feature matrix (as doubles) and the optional label
  x$xgb.DMatrix <- function(data, label = NULL, ...) {
    m <- as.matrix(data); storage.mode(m) <- "double"
    structure(list(x = m, y = if (is.null(label)) NULL else as.numeric(label)), class = "xgb.DMatrix")
  }
  dim.xgb.DMatrix <- function(x) dim(x$x)

  # grow(): builds one regression tree recursively from gradients g on the given rows; returns a nested list.
  # ords[[f]]: this node's rows with non-missing values of feature f, sorted by value.
  # Children inherit their slices of these orders, so each node costs time proportional to its own size.
  # out$upd[rows] receives each training row's leaf value, so training predictions need no extra pass.
  grow <- function(X, ords, g, rows, depth, P, out) {
    G <- sum(g[rows]); H <- length(rows); lam <- P$lambda; mcw <- P$min_child_weight
    leaf <- list(leaf = TRUE, value = -G / (H + lam) * P$eta, cover = H)
    if (depth >= P$max_depth || H < 2 * mcw) { out$upd[rows] <- leaf$value; return(leaf) }
    base <- G^2 / (H + lam); best <- list(gain = 1e-6)
    # Ties (equal gain up to rounding) are broken as xgboost does: the lower feature index wins, and
    # within a feature the first threshold visited wins (backward scans start from the largest value).
    consider <- function(f, GL, HL, thr, dl) {
      if (!length(GL)) return()
      GR <- G - GL; HR <- H - HL
      gain <- 0.5 * (GL^2 / (HL + lam) + GR^2 / (HR + lam) - base) - P$gamma
      gain[HL < mcw | HR < mcw] <- -Inf
      top <- max(gain); if (!is.finite(top)) return()
      near <- which(gain >= top - 1e-9 * abs(top))
      j <- if (dl) near[length(near)] else near[1]
      if (gain[j] > best$gain + 1e-9 * abs(best$gain)) best <<- list(gain = gain[j], f = f, thr = thr[j], default_left = dl)
    }
    for (f in seq_along(ords)) {
      idx <- ords[[f]]; n <- length(idx)
      if (!n) next
      vs <- X[idx, f]; gs <- g[idx]; nmiss <- H - n
      cl <- cumsum(gs); Gm <- G - cl[n]
      cand <- which(vs[-n] != vs[-1]); thr <- (vs[cand] + vs[cand + 1]) / 2
      if (nmiss > 0) {                                   # forward scan: missing values go right
        consider(f, cl[cand], cand, thr, FALSE)
        consider(f, cl[n], n, vs[n] + 1e-6, FALSE)       # all present values left, missing right
      }
      consider(f, cl[cand] + Gm, cand + nmiss, thr, TRUE) # backward scan: missing values go left
      if (nmiss > 0) consider(f, Gm, nmiss, vs[1] - 1e-6, TRUE)
    }
    if (is.null(best$f)) { out$upd[rows] <- leaf$value; return(leaf) }
    v <- X[rows, best$f]
    goL <- if (anyNA(v)) ifelse(is.na(v), best$default_left, v < best$thr) else v < best$thr
    inL <- logical(nrow(X)); inL[rows[goL]] <- TRUE
    list(leaf = FALSE, f = best$f, thr = best$thr, default_left = best$default_left, gain = 2 * best$gain, cover = H,
         left  = grow(X, lapply(ords, function(o) o[inL[o]]),  g, rows[goL],  depth + 1, P, out),
         right = grow(X, lapply(ords, function(o) o[!inL[o]]), g, rows[!goL], depth + 1, P, out))
  }
  # tree_pred(): sends every row of X down tree t and returns its leaf values
  tree_pred <- function(t, X) {
    out <- numeric(nrow(X))
    walk <- function(t, idx) {
      if (!length(idx)) return()
      if (t$leaf) { out[idx] <<- t$value; return() }
      goL <- X[idx, t$f] < t$thr; goL[is.na(goL)] <- t$default_left
      walk(t$left, idx[goL]); walk(t$right, idx[!goL])
    }
    walk(t, seq_len(nrow(X))); out
  }

  # xgb.train(): boosting loop. Each round fits a tree to the current residual gradients, adds it to the
  # predictions, records RMSE on the evals sets, and stops early if the last eval set stops improving.
  x$xgb.train <- function(params = list(), data, nrounds, evals = list(), early_stopping_rounds = NULL, verbose = 1, ...) {
    P <- modifyList(list(eta = 0.3, max_depth = 6, lambda = 1, gamma = 0, min_child_weight = 1, subsample = 1), params)
    P$eta <- as.numeric(P$eta); P$max_depth <- as.numeric(P$max_depth)
    X <- data$x; y <- data$y; base <- mean(y)
    pred <- rep(base, length(y)); trees <- list()
    ev <- lapply(evals, function(d) list(X = d$x, y = d$y, p = rep(base, nrow(d$x))))
    log <- list(); best <- list(score = Inf, iter = 0L)
    ord <- lapply(seq_len(ncol(X)), function(f) { o <- order(X[, f]); o[!is.na(X[o, f])] })
    out <- new.env()
    for (it in seq_len(nrounds)) {
      rows <- seq_along(y); o <- ord
      if (P$subsample < 1) {
        rows <- sort(sample.int(length(y), floor(P$subsample * length(y))))
        keep <- logical(length(y)); keep[rows] <- TRUE; o <- lapply(ord, function(v) v[keep[v]])
      }
      out$upd <- numeric(length(y))
      t <- grow(X, o, pred - y, rows, 0, P, out)
      trees[[it]] <- t
      pred <- pred + if (length(rows) == length(y)) out$upd else tree_pred(t, X)
      if (length(ev)) {
        sc <- vapply(names(ev), function(nm) { ev[[nm]]$p <<- ev[[nm]]$p + tree_pred(t, ev[[nm]]$X); sqrt(mean((ev[[nm]]$y - ev[[nm]]$p)^2)) }, 0)
        log[[it]] <- sc
        if (!is.null(early_stopping_rounds)) {
          if (sc[length(sc)] < best$score) best <- list(score = sc[[length(sc)]], iter = it)
          else if (it - best$iter >= early_stopping_rounds) break
        }
      }
    }
    if (length(ev)) { m <- do.call(rbind, log); log <- data.frame(iter = seq_len(nrow(m)), m); names(log)[-1] <- paste0(names(ev), "_rmse") }
    structure(list(trees = trees, base = base, features = colnames(X)), class = "xgb.Booster",
              evaluation_log = if (length(ev)) log else NULL,
              early_stop = if (!is.null(early_stopping_rounds)) list(best_iteration = best$iter, best_score = c(best$score), stopped_by_max_rounds = it == nrounds) else NULL)
  }

  # E[f(x) | x_S] for one tree, path-dependent (cover-weighted), as in TreeSHAP
  cond_exp <- function(t, xr, S) {
    if (t$leaf) return(t$value)
    if (t$f %in% S) {
      v <- xr[t$f]; goL <- if (is.na(v)) t$default_left else v < t$thr
      return(cond_exp(if (goL) t$left else t$right, xr, S))
    }
    (t$left$cover * cond_exp(t$left, xr, S) + t$right$cover * cond_exp(t$right, xr, S)) / t$cover
  }
  # used(): the features a tree splits on; shap_tree(): exact Shapley values for one tree, one row
  # (enumerates every subset of the used features; fine for the shallow trees in these labs)
  used <- function(t) if (t$leaf) integer(0) else unique(c(t$f, used(t$left), used(t$right)))
  shap_tree <- function(t, xr, p) {
    phi <- numeric(p + 1); U <- used(t); m <- length(U)
    phi[p + 1] <- cond_exp(t, xr, integer(0))
    if (!m) return(phi)
    masks <- 0:(2^m - 1); bits <- 2^(seq_len(m) - 1)
    val <- vapply(masks, function(b) cond_exp(t, xr, U[bitwAnd(b, bits) > 0]), 0)
    size <- vapply(masks, function(b) sum(bitwAnd(b, bits) > 0), 0)
    for (k in seq_len(m)) {
      without <- masks[bitwAnd(masks, bits[k]) == 0]
      w <- factorial(size[without + 1]) * factorial(m - size[without + 1] - 1) / factorial(m)
      phi[U[k]] <- sum(w * (val[without + bits[k] + 1] - val[without + 1]))
    }
    phi
  }

  # predict(): sums the trees' outputs plus the base score; with predcontrib = TRUE returns SHAP values
  # (one column per feature plus "(Intercept)"). Honors early stopping's best iteration, like xgboost.
  predict.xgb.Booster <- function(object, newdata, predcontrib = FALSE, iterationrange = NULL, ...) {
    X <- if (inherits(newdata, "xgb.DMatrix")) newdata$x else as.matrix(newdata)
    n_use <- length(object$trees)
    es <- attr(object, "early_stop"); if (is.null(iterationrange) && !is.null(es)) n_use <- es$best_iteration
    if (!is.null(iterationrange)) n_use <- iterationrange[2]
    trees <- object$trees[seq_len(n_use)]
    if (!predcontrib) return(object$base + Reduce(`+`, lapply(trees, function(t) tree_pred(t, X)), numeric(nrow(X))))
    p <- ncol(X)
    S <- t(vapply(seq_len(nrow(X)), function(i) Reduce(`+`, lapply(trees, shap_tree, xr = X[i, ], p = p)), numeric(p + 1)))
    if (nrow(X) == 1) S <- matrix(S, nrow = 1)
    S[, p + 1] <- S[, p + 1] + object$base
    colnames(S) <- c(object$features, "(Intercept)"); S
  }

  # xgb.importance(): Gain, Cover and Frequency shares per feature, summed over all splits
  x$xgb.importance <- function(model, ...) {
    acc <- list()
    walk <- function(t) if (!t$leaf) {
      nm <- model$features[t$f]; a <- acc[[nm]]; if (is.null(a)) a <- c(0, 0, 0)
      acc[[nm]] <<- a + c(t$gain, t$cover, 1); walk(t$left); walk(t$right) }
    for (t in model$trees) walk(t)
    m <- do.call(rbind, acc)
    out <- data.frame(Feature = rownames(m), Gain = m[, 1] / sum(m[, 1]), Cover = m[, 2] / sum(m[, 2]), Frequency = m[, 3] / sum(m[, 3]), row.names = NULL)
    out[order(-out$Gain), ]
  }
  print.xgb.Booster <- function(x, ...) cat(sprintf("xgb.Booster (browser edition): %d trees\n", length(x$trees)))

  # register the methods, attach the fake package, and tell the student a substitute is in use
  registerS3method("predict", "xgb.Booster", predict.xgb.Booster)
  registerS3method("print", "xgb.Booster", print.xgb.Booster)
  registerS3method("dim", "xgb.DMatrix", dim.xgb.DMatrix)
  attach(x, name = "package:xgboost", warn.conflicts = FALSE)
  message("Note: xgboost's compiled code cannot run inside the browser yet, so this page uses a pure-R version of ",
          "the same exact-greedy algorithm. Results match the CRAN package with tree_method = \"exact\".")
})
