# Usage (from site/): Rscript tools/check_lab.R src/labs/ch03/benchmarks.R [more files...]
# Runs a lab exactly as the browser would (course helpers + bundled data), reports errors and charts emitted.
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(".")
for (f in args) {
  path <- normalizePath(f)
  cat("\n==== ", f, " ====\n", sep = "")
  setwd(file.path(root, "public"))
  rm(list = setdiff(ls(globalenv()), c("args", "root", "f", "path")), envir = globalenv())
  if ("course" %in% search()) detach("course")
  source("r/course.R")
  code <- readLines(path, warn = FALSE, encoding = "UTF-8")
  code <- code[!grepl("^[[:space:]]*#[|]", code)]
  t0 <- Sys.time()
  ok <- tryCatch({
    exprs <- parse(text = code, keep.source = FALSE)
    for (e in exprs) { v <- withVisible(eval(e, envir = globalenv())); if (v$visible) print(v$value) }
    TRUE
  }, error = function(e) { cat("ERROR:", conditionMessage(e), "\n"); FALSE })
  viz <- jsonlite::fromJSON(.course_viz_pop(), simplifyVector = FALSE)
  cat(sprintf("\n-> %s in %.1fs; %d chart(s): %s\n", if (ok) "OK" else "FAILED", as.numeric(Sys.time() - t0, units = "secs"),
              length(viz), paste(vapply(viz, function(v) paste0(v$type, if (!is.null(v$title)) paste0(" '", v$title, "'") else ""), ""), collapse = "; ")))
  setwd(root)
}
