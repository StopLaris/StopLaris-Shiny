args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", grep("^--file=", args, value = TRUE)[1])
if (!is.na(script)) setwd(dirname(dirname(normalizePath(script))))
if (!requireNamespace("testthat", quietly = TRUE)) stop("Testler için install.packages('testthat') çalıştırın.")
dir.create("validation", showWarnings = FALSE)
Sys.setenv(STOPLARIS_TEST_ROOT = normalizePath("."))
result <- testthat::test_dir("tests", filter = "^(data|server|patient_assessment)$", reporter = "summary", stop_on_failure = FALSE)
frame <- as.data.frame(result)
jsonlite::write_json(list(timestamp_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  R = R.version.string, shiny = as.character(packageVersion("shiny")),
  tests = nrow(frame), assertions = sum(frame$nb), failed = sum(frame$failed),
  errors = sum(frame$error), skipped = sum(frame$skipped),
  passed = sum(frame$passed), details = frame[, setdiff(names(frame), "result"), drop = FALSE]),
  "validation/r_tests.json", auto_unbox = TRUE, pretty = TRUE, na = "null")
writeLines(capture.output(sessionInfo()), "validation/sessionInfo.txt")
if (any(frame$failed > 0 | frame$error)) quit(status = 1L)
