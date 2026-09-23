library(testthat)
app_root <- Sys.getenv("STOPLARIS_TEST_ROOT", normalizePath(".."))
source(file.path(app_root, "R", "data.R"), local = TRUE)
source(file.path(app_root, "R", "app_ui.R"), local = TRUE)
source(file.path(app_root, "R", "app_server.R"), local = TRUE)
source(file.path(app_root, "R", "patient_assessment.R"), local = TRUE)
fixture <- load_stoplaris_data(file.path(app_root, "data"))
server_for_test <- app_server
formals(server_for_test)$data <- quote(fixture)

test_that("actual server filters cohorts, patients, classes and expression", {
  shiny::testServer(server_for_test, {
    session$setInputs(explorer_dataset = "GSE173278", explorer_patient = "__all__",
      explorer_cell_type = "__all__", explorer_feature = "USP9X", explorer_group = "cell_type",
      explorer_range = c(0, 100), model_stage = "expanded_grid")
    expect_equal(nrow(filtered_cells()), 842L)
    expect_true(umap_available())
    expect_equal(nrow(current_patients()), 10L)
    expect_equal(main_patient_f1(), 0.8840518603780836)
    session$setInputs(explorer_patient = "JK124")
    expect_equal(nrow(filtered_cells()), 96L)
    expect_true(all(filtered_cells()$patient_id == "JK124"))
    session$setInputs(explorer_patient = "__all__", explorer_cell_type = "myCAF_like")
    expect_equal(nrow(filtered_cells()), 188L)
    session$setInputs(explorer_cell_type = "__all__", explorer_range = c(0.00001, 100))
    expect_equal(nrow(filtered_cells()), 192L)
    session$setInputs(explorer_dataset = "GSE97930", explorer_patient = "__all__", explorer_range = c(0, 100))
    expect_equal(nrow(filtered_cells()), 10253L)
    expect_false(umap_available())
    expect_equal(sum(healthy_summary()$n_cells), 10253L)
    session$setInputs(explorer_dataset = "GSE141946")
    expect_equal(nrow(filtered_cells()), 1404L)
    expect_equal(length(unique(filtered_cells()$patient_id)), 3L)
    expect_false(umap_available())
    session$setInputs(model_stage = "calibrated")
    expect_equal(main_patient_f1(current_stage()), 0.8848715428001922)
    expect_true(all(current_metrics()$stage == "calibrated"))
  })
})

test_that("outputs render and actual download handlers write valid files", {
  shiny::testServer(server_for_test, {
    session$setInputs(explorer_dataset = "GSE173278", explorer_patient = "JK124",
      explorer_cell_type = "__all__", explorer_feature = "USP9X", explorer_group = "cell_type",
      explorer_range = c(0, 100), model_stage = "expanded_grid")
    expect_s3_class(feature_plot(), "ggplot")
    expect_s3_class(umap_plot(), "ggplot")
    expect_match(as.character(output$overview_kpis$html), "0,884", fixed = TRUE)
    expect_match(as.character(output$overview_kpis$html), "0,000999", fixed = TRUE)
    expect_match(as.character(output$permutation_content$html), "Permütasyon", fixed = TRUE)
    expect_true(nchar(output$cell_table) > 0)
    expect_true(nchar(output$metrics_table) > 0)
    expect_true(nchar(output$healthy_summary_table) > 0)
    expect_true(nchar(output$sources_table) > 0)
    cell_file <- output$download_cells
    downloaded <- stoplaris_read_csv(cell_file)
    expect_equal(nrow(downloaded), 96L)
    expect_true(all(downloaded$patient_id == "JK124"))
    metric_file <- output$download_metrics
    expect_equal(nrow(stoplaris_read_csv(metric_file)), 7L)
    for (path in c(output$download_feature_plot, output$download_umap)) {
      con <- file(path, "rb"); bytes <- readBin(con, "raw", n = 8); close(con)
      expect_identical(bytes, as.raw(c(137,80,78,71,13,10,26,10)))
      expect_gt(file.info(path)$size, 1000)
    }
    prov <- jsonlite::read_json(output$download_provenance)
    expect_equal(prov$metadata$data_version, "V5_STAGE2_2026-09-20")
  })
})

test_that("uploaded cells stay session-local and leave model metrics fixed", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  sample <- fixture$cells[fixture$cells$dataset == "GSE173278", ][1:5, ]
  safe_export_csv(sample, path)
  shiny::testServer(server_for_test, {
    session$setInputs(model_stage = "expanded_grid", explorer_dataset = "GSE173278")
    before <- current_metrics()
    session$setInputs(upload_cells = data.frame(name = "real_cell_subset.csv", size = file.info(path)$size,
      type = "text/csv", datapath = path))
    expect_equal(nrow(uploaded()), 5L)
    expect_false(upload_error())
    session$setInputs(explorer_dataset = "__uploaded__", explorer_patient = "__all__",
      explorer_cell_type = "__all__", explorer_range = c(0, 100))
    expect_equal(nrow(filtered_cells()), 5L)
    expect_equal(current_metrics(), before)
    expect_true(all(filtered_cells()$prediction_type == "user_supplied_unvalidated"))
    session$setInputs(clear_upload = 1)
    expect_null(uploaded())
    session$setInputs(explorer_dataset = "GSE173278")
    expect_equal(nrow(filtered_cells()), 842L)
  })
})
