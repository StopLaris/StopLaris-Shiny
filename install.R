# Run once on a computer with R installed: Rscript install.R
required <- c("shiny", "jsonlite", "ggplot2", "DT")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  destination <- Sys.getenv("R_LIBS_USER")
  if (!nzchar(destination)) destination <- file.path(path.expand("~"), "R", "StopLaris-library")
  destination <- strsplit(destination, .Platform$path.sep, fixed = TRUE)[[1]][1]
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  .libPaths(unique(c(destination, .libPaths())))
  install.packages(missing, repos = "https://cloud.r-project.org", lib = destination)
}
if (any(!vapply(required, requireNamespace, logical(1), quietly = TRUE)))
  stop("Bazı paketler kurulamadı. İnternet bağlantısını ve R konsolundaki hata mesajını kontrol edin.")
cat("StopLaris bağımlılıkları hazır. Rscript run_app.R komutuyla açabilirsiniz.\n")
