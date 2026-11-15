# ─────────────────────────────────────────────────────────────
#  Forecast Lab course helpers (loaded automatically in the browser)
#  fred()  → read a bundled FRED series as a ts object
#  viz_*() → send a chart to the interactive web page
#  These helpers live in an attached "course" environment so they
#  never clutter ls().
# ─────────────────────────────────────────────────────────────
local({
course <- new.env()
.q <- new.env(); .q$items <- list(); .q$hash <- list(); .q$src <- character(0)

course$.course_src <- function() if (length(.q$src)) paste0("FRED, Federal Reserve Bank of St. Louis (", paste(.q$src, collapse = ", "), ")") else NULL
# Exercise checks: check_that(abs(mean(x) - 5) < 0.01, "Nice — that's the sample mean.", "Hint: use mean().")
course$check_that <- function(cond, pass = "Well done.", fail = "Not quite yet. Try again.") {
  ok <- isTRUE(tryCatch(cond, error = function(e) FALSE))
  .course_push(list(type = "check", pass = ok, message = if (ok) pass else fail)); invisible(ok)
}
course$.course_push <- function(spec) { .q$items[[length(.q$items) + 1]] <- spec; invisible(NULL) }
course$.course_viz_pop <- function() {
  s <- jsonlite::toJSON(.q$items, auto_unbox = TRUE, digits = 8, na = "null", null = "null")
  .q$items <- list(); as.character(s)
}

# ── dates for any ts ───────────────────────────────────────────
course$ts_dates <- function(x) {
  tt <- as.numeric(time(x)); f <- frequency(x)
  yr <- floor(tt + 1e-8)
  if (f == 12) return(sprintf("%04d-%02d-01", yr, as.integer(round((tt - yr) * 12)) + 1L))
  if (f == 4)  return(sprintf("%04d-%02d-01", yr, as.integer(round((tt - yr) * 4)) * 3L + 1L))
  if (f == 1)  return(sprintf("%04d-01-01", yr))
  format(as.Date(sprintf("%04d-01-01", yr)) + round((tt - yr) * 365.25))
}

# ── data ───────────────────────────────────────────────────────
course$fred <- function(id, start = NULL, end = NULL, to = NULL, quiet = FALSE) {
  # Reads a bundled FRED series and returns a ts on its true calendar grid.
  # - Monthly/quarterly/annual data: missing periods stay in place (no silent shifting);
  #   gaps of 1-2 periods are filled by linear interpolation (with a note);
  #   if an older stretch has longer gaps, the series starts after it.
  # - Daily data is averaged to monthly by default (a ts cannot hold trading days);
  #   use to = "quarter" for quarterly, or read.csv() for the raw daily file.
  path <- file.path("data", paste0(id, ".csv"))
  if (!file.exists(path)) stop("No bundled series '", id, "'. Try: list.files('data')")
  .q$src <- unique(c(id, .q$src))[seq_len(min(6, length(unique(c(id, .q$src)))))]
  d <- read.csv(path, na.strings = c(".", "", "NA"))
  d[[1]] <- as.Date(d[[1]]); d <- d[!is.na(d[[2]]), ]
  gap0 <- median(as.numeric(diff(d[[1]])))
  if (is.null(to) && gap0 <= 5) {
    to <- "month"
    if (!quiet) message("Note: ", id, " is daily; returning monthly averages (use to = \"quarter\" for quarterly).")
  }
  if (!is.null(to) && to %in% c("month", "quarter")) {
    key <- if (to == "month") format(d[[1]], "%Y-%m-01") else
      sprintf("%s-%02d-01", format(d[[1]], "%Y"), (as.integer(format(d[[1]], "%m")) - 1) %/% 3 * 3 + 1)
    agg <- tapply(d[[2]], key, mean); d <- data.frame(as.Date(names(agg)), as.numeric(agg))
  }
  gap <- median(as.numeric(diff(d[[1]])))
  f <- if (gap > 300) 1 else if (gap > 80) 4 else if (gap > 25) 12 else 365.25 / 7
  by <- switch(as.character(f), "1" = "year", "4" = "quarter", "12" = "month", "7 days")
  grid <- seq(d[[1]][1], d[[1]][nrow(d)], by = by)
  v <- d[[2]][match(grid, d[[1]])]
  y <- as.integer(format(grid[1], "%Y")); m <- as.integer(format(grid[1], "%m"))
  st <- if (f == 1) y else if (f == 4) c(y, (m - 1) %/% 3 + 1) else if (f == 12) c(y, m) else y + (as.numeric(format(grid[1], "%j")) - 1) / 365.25
  x <- ts(v, start = st, frequency = f)
  if (!is.null(start)) x <- window(x, start = start)
  if (!is.null(end)) x <- window(x, end = end)
  # handle gaps inside the requested window
  na <- is.na(x)
  if (any(na)) {
    r <- rle(na); ends <- cumsum(r$lengths)
    long <- if (sum(na) > 3) which(r$values) else which(r$values & r$lengths > 2)  # many gaps: don't invent data
    if (length(long)) {
      cut <- ends[max(long)] + 1
      if (!quiet) message("Note: ", id, " has gaps before ", ts_dates(x)[cut], "; the series starts there.")
      x <- window(x, start = time(x)[cut])
    }
    x <- window(x, start = time(x)[which(!is.na(x))[1]], end = time(x)[max(which(!is.na(x)))])
    na <- is.na(x)
    if (any(na)) {
      if (!quiet) message("Note: ", id, " has no value for ", paste(ts_dates(x)[na], collapse = ", "),
                          " (e.g. the 2025 government shutdown); filled by linear interpolation.")
      x[na] <- stats::approx(seq_along(x), as.numeric(x), xout = which(na))$y
    }
  }
  x
}

.ser <- function(x, name = "series") {
  x <- as.ts(x)
  list(name = name, date = ts_dates(x), value = as.numeric(x))
}

# ── charts ─────────────────────────────────────────────────────
# Line chart of one or more ts objects: viz_ts(retail, title = "...")  or viz_ts(a = x1, b = x2)
course$viz_ts <- function(..., title = NULL, subtitle = NULL, ylab = NULL, recessions = FALSE, facet = FALSE, log = FALSE, source = .course_src()) {
  args <- list(...); nm <- names(args)
  if (is.null(nm)) nm <- rep("", length(args))
  dots <- as.list(substitute(list(...)))[-1]
  for (i in seq_along(args)) if (nm[i] == "") nm[i] <- deparse(dots[[i]])[1]
  series <- lapply(seq_along(args), function(i) .ser(args[[i]], nm[i]))
  rec <- NULL
  if (isTRUE(recessions) && file.exists("data/USREC.csv")) {
    r <- read.csv("data/USREC.csv"); r <- r[r[[2]] == 1, 1]; rec <- r
  }
  .course_push(list(source = source, type = "ts", title = title, subtitle = subtitle, ylab = ylab, series = series,
                    recessions = rec, facet = facet, log = log))
}

# Forecast fan chart. fc = a forecast() object; actual = held-out test data (optional)
course$viz_forecast <- function(fc, actual = NULL, title = NULL, subtitle = NULL, from = NULL, ylab = NULL, fitted = FALSE, source = .course_src()) {
  x <- fc$x; if (!is.null(from)) x <- window(x, start = from)
  spec <- list(type = "forecast", title = if (is.null(title)) fc$method else title, subtitle = subtitle, ylab = ylab,
               method = fc$method, history = .ser(x, "history"), mean = .ser(fc$mean, "forecast"))
  if (!is.null(fc$lower)) {
    lv <- colnames(fc$lower); if (is.null(lv)) lv <- paste0(fc$level, "%")
    spec$bands <- lapply(seq_along(lv), function(i) list(level = lv[i], lo = as.numeric(fc$lower[, i]), hi = as.numeric(fc$upper[, i])))
  }
  if (!is.null(actual)) spec$actual <- .ser(actual, "actual")
  if (isTRUE(fitted) && !is.null(fc$fitted)) { ff <- fc$fitted; if (!is.null(from)) ff <- window(ff, start = from); spec$fitted <- .ser(ff, "fitted") }
  .course_push(spec)
}

# Several forecasts on one chart: viz_compare(actual = test, Naive = f1, ETS = f2, history = train)
course$viz_compare <- function(..., history = NULL, actual = NULL, title = NULL, subtitle = NULL, from = NULL, source = .course_src()) {
  fcs <- list(...)
  h <- if (!is.null(history)) { if (!is.null(from)) window(history, start = from) else history } else NULL
  .course_push(list(source = source, type = "compare", title = title, subtitle = subtitle,
                    history = if (!is.null(h)) .ser(h, "history") else NULL,
                    actual = if (!is.null(actual)) .ser(actual, "actual") else NULL,
                    models = lapply(names(fcs), function(n) { f <- fcs[[n]]; m <- if (is.list(f) && !is.null(f$mean)) f$mean else f; .ser(m, n) })))
}

# Table (data.frame) with optional best-value highlighting: viz_table(scores, highlight = "RMSE")
course$viz_table <- function(df, title = NULL, subtitle = NULL, highlight = NULL, digits = 3, lower_is_better = TRUE, source = .course_src()) {
  df <- as.data.frame(df)
  if (!is.null(rownames(df)) && !identical(rownames(df), as.character(seq_len(nrow(df))))) df <- cbind(Model = rownames(df), df)
  for (j in seq_along(df)) if (is.numeric(df[[j]])) df[[j]] <- round(df[[j]], digits)
  .course_push(list(source = source, type = "table", title = title, subtitle = subtitle, columns = names(df), rows = unname(lapply(seq_len(nrow(df)), function(i) unname(as.list(df[i, ])))),
                    highlight = highlight, lower_is_better = lower_is_better))
}

course$viz_bars <- function(values, labels = names(values), title = NULL, subtitle = NULL, xlab = NULL, sort = TRUE, highlight = NULL, source = .course_src()) {
  .course_push(list(source = source, type = "bars", title = title, subtitle = subtitle, xlab = xlab, labels = as.character(labels), values = as.numeric(values), sort = sort, highlight = highlight))
}

course$viz_scatter <- function(x, y, title = NULL, subtitle = NULL, xlab = NULL, ylab = NULL, fit = TRUE, labels = NULL, source = .course_src()) {
  xl <- if (is.null(xlab)) deparse(substitute(x)) else xlab; yl <- if (is.null(ylab)) deparse(substitute(y)) else ylab
  .course_push(list(source = source, type = "scatter", title = title, subtitle = subtitle, xlab = xl, ylab = yl, x = as.numeric(x), y = as.numeric(y), fit = fit, labels = labels))
}

course$viz_acf <- function(x, lag.max = 36, type = c("acf", "pacf"), title = NULL, source = .course_src()) {
  type <- match.arg(type)
  a <- if (type == "acf") acf(x, lag.max = lag.max, plot = FALSE, na.action = na.pass) else pacf(x, lag.max = lag.max, plot = FALSE, na.action = na.pass)
  lags <- as.numeric(a$lag) * frequency(x); v <- as.numeric(a$acf)
  if (type == "acf") { lags <- lags[-1]; v <- v[-1] }
  .course_push(list(source = source, type = "acf", kind = toupper(type), title = title, lag = round(lags), value = v, ci = 1.96 / sqrt(sum(!is.na(x)))))
}

# Decomposition panel from stl() or decompose()
course$viz_decomp <- function(d, title = NULL, source = .course_src()) {
  if (inherits(d, "stl")) { s <- d$time.series; parts <- list(data = rowSums(s), trend = s[, "trend"], seasonal = s[, "seasonal"], remainder = s[, "remainder"])
    parts <- lapply(parts, function(p) ts(p, start = start(s), frequency = frequency(s))) }
  else parts <- list(data = d$x, trend = d$trend, seasonal = d$seasonal, remainder = d$random)
  .course_push(list(source = source, type = "decomp", title = title, parts = lapply(names(parts), function(n) .ser(parts[[n]], n))))
}

# Big number cards: viz_kpi(RMSE = 1234, MAPE = "3.2%")
course$viz_kpi <- function(..., title = NULL) {
  v <- list(...); .course_push(list(type = "kpi", title = title, items = lapply(names(v), function(n) list(label = n, value = v[[n]]))))
}

# Lines against a numeric x: viz_lines(1:12, `Seasonal naive` = mae1, Drift = mae2, xlab = "horizon")
course$viz_lines <- function(x, ..., title = NULL, subtitle = NULL, xlab = NULL, ylab = NULL, zero = FALSE, source = .course_src()) {
  ys <- list(...)
  .course_push(list(source = source, type = "lines", title = title, subtitle = subtitle, xlab = xlab, ylab = ylab, zero = zero, x = as.numeric(x),
                    series = lapply(names(ys), function(n) list(name = n, value = as.numeric(ys[[n]])))))
}

# Pipe arbitrary long-format data to any registered chart type (advanced)
course$viz_custom <- function(type, ..., source = .course_src()) .course_push(c(list(type = type, source = source), list(...)))

# ── step-through support ───────────────────────────────────────
course$.course_parse_steps <- function(code) {
  p <- parse(text = code, keep.source = TRUE); sr <- attr(p, "srcref")
  as.character(jsonlite::toJSON(lapply(sr, function(s) list(start = s[1], end = s[3])), auto_unbox = TRUE))
}
.fp <- function(x) { r <- tryCatch(serialize(x, NULL), error = function(e) raw(0)); n <- length(r)
  if (n == 0) return("0"); i <- unique(round(seq(1, n, length.out = min(n, 4000)))); paste(n, sum(as.integer(r[i]) * seq_along(i))) }
course$.course_inspect_reset <- function() .q$hash <- list()
course$.course_inspect <- function() {
  nms <- ls(globalenv()); out <- list(); newhash <- list()
  for (n in nms) {
    x <- get(n, envir = globalenv()); h <- .fp(x); newhash[[n]] <- h
    status <- if (is.null(.q$hash[[n]])) "new" else if (!identical(.q$hash[[n]], h)) "changed" else "same"
    cls <- class(x)[1]; info <- list(name = n, class = cls, status = status)
    if (is.ts(x)) { info$summary <- sprintf("ts [%d obs, %s – %s, freq %g]", length(x), ts_dates(x)[1], tail(ts_dates(x), 1), frequency(x)); v <- as.numeric(x); info$spark <- if (length(v) > 400) v[round(seq(1, length(v), length.out = 400))] else v }
    else if (is.data.frame(x)) { info$summary <- sprintf("data.frame [%d rows × %d cols]", nrow(x), ncol(x)); hd <- utils::head(x, 5)
      info$table <- list(columns = names(hd), rows = unname(lapply(seq_len(nrow(hd)), function(i) unname(lapply(hd[i, ], function(v) if (is.numeric(v)) signif(v, 5) else as.character(v)))))) }
    else if (is.numeric(x) && is.null(dim(x)) && length(x) > 1) { info$summary <- sprintf("%s [%d] %s", cls, length(x), paste(signif(utils::head(x, 4), 4), collapse = ", ")); v <- as.numeric(x); if (length(x) > 5) info$spark <- if (length(v) > 400) v[round(seq(1, length(v), length.out = 400))] else v }
    else if (is.atomic(x) && length(x) == 1) info$summary <- paste(cls, ":", format(x, digits = 6))
    else if (is.matrix(x)) info$summary <- sprintf("matrix [%d × %d]", nrow(x), ncol(x))
    else if (inherits(x, "forecast")) info$summary <- sprintf("forecast — %s, h = %d", x$method, length(x$mean))
    else if (inherits(x, c("lm", "glm"))) info$summary <- sprintf("%s: %s", cls, paste(deparse(formula(x)), collapse = ""))
    else if (is.function(x)) info$summary <- "function"
    else { pr <- tryCatch(trimws(utils::capture.output(print(x))), error = function(e) character(0)); pr <- pr[nzchar(pr)]
      info$summary <- if (length(pr)) substr(paste(utils::head(pr, 2), collapse = " · "), 1, 140) else sprintf("%s (length %d)", cls, length(x)) }
    out[[length(out) + 1]] <- info
  }
  .q$hash <- newhash
  as.character(jsonlite::toJSON(out, auto_unbox = TRUE, digits = 6, na = "null"))
}

attach(course, name = "course", warn.conflicts = FALSE)
})
if (dir.exists("/home/web_user")) setwd("/home/web_user")
options(digits = 5, width = 90, scipen = 6, warn = 1)
invisible(NULL)
