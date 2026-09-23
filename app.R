# Run from this folder: shiny::runApp(".")
required_packages <- c("shiny", "ggplot2", "DT", "jsonlite")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop(paste0("Eksik R paketleri: ", paste(missing_packages, collapse = ", "), ". Önce Rscript install.R çalıştırın."), call. = FALSE)
}
options(shiny.maxRequestSize = 50 * 1024^2, shiny.sanitize.errors = TRUE)
source(file.path("R", "data.R"), local = TRUE)
source(file.path("R", "app_ui.R"), local = TRUE)
source(file.path("R", "app_server.R"), local = TRUE)
source(file.path("R", "patient_assessment.R"), local = TRUE)
stoplaris_data <- load_stoplaris_data("data")
shiny::shinyApp(ui = app_ui(), server = function(input, output, session) {
  app_server(input, output, session, data = stoplaris_data)
})
