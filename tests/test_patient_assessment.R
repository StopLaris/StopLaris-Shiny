library(testthat)
app_root <- Sys.getenv("STOPLARIS_TEST_ROOT", normalizePath(".."))
source(file.path(app_root, "R", "data.R"), local = FALSE)
source(file.path(app_root, "R", "patient_assessment.R"), local = FALSE)

test_that("rank index is bounded, monotone, tie-aware and explicit about invalid references", {
  ranked <- patient_rank_index(c(0, .1, .2, .3))
  expect_equal(ranked$score_0_10, c(0, 10/3, 20/3, 10))
  expect_equal(patient_rank_index(c(3, 1, 2))$score_0_10, c(10, 0, 5))
  expect_equal(patient_rank_index(c(0, 1, 1, 2))$score_0_10, c(0, 5, 5, 10))
  expect_equal(patient_rank_index(rep(0, 4))$score_0_10, rep(5, 4))
  expect_error(patient_rank_index(0), "en az iki")
  expect_error(patient_rank_index(c(0, NA)), "sonlu")
  expect_error(patient_rank_index(c(0, Inf)), "sonlu")
  expect_error(patient_rank_index(c(0, -1)), "negatif")
  expect_error(patient_rank_index(c("0", "1")), "sonlu")
})

test_that("reference uses only complete verified development patients and actual source expression", {
  data <- load_stoplaris_data(file.path(app_root, "data"))
  ref <- patient_reference_from_data(data)
  expect_equal(ref$reference_n_cells, 842L)
  expect_equal(ref$reference_n_patients, 10L)
  expect_identical(ref$dataset, "GSE173278")
  expect_false(ref$clinical_risk_available)
  expect_true(all(ref$table$score_0_10 >= 0 & ref$table$score_0_10 <= 10))
  expect_equal(range(ref$table$n_cells), c(6L, 352L))
  for (id in ref$table$patient_id) {
    source <- data$cells[data$cells$dataset == "GSE173278" & !is.na(data$cells$patient_id) & data$cells$patient_id == id, ]
    result <- patient_profile_summary(ref, id)
    expect_equal(result$summary$mean_USP9X, mean(source$USP9X), tolerance = 1e-14)
    expect_equal(sum(result$subtype$n_cells), nrow(source))
    expect_equal(sum(result$subtype$cell_fraction), 1)
  }
  sparse <- patient_profile_summary(ref, "JK126")
  expect_equal(sparse$summary$n_cells, 6L)
  expect_equal(sparse$summary$score_0_10, 10)
  expect_true(any(sparse$subtype$n_cells == 0 & is.na(sparse$subtype$mean_USP9X)))
  expect_error(patient_profile_summary(ref, "new_patient"), "bulunmuyor")
  expect_error(patient_profile_summary(ref, NA_character_), "bulunmuyor")
})

test_that("incomplete, uploaded, invalid and wrong-version references fail closed", {
  data <- load_stoplaris_data(file.path(app_root, "data"))
  bad <- data; bad$cells <- bad$cells[-1, ]
  expect_error(patient_reference_from_data(bad), "Sabit hasta referansı")
  bad <- data; bad$cells$prediction_type[bad$cells$dataset == "GSE173278"] <- "user_supplied_unvalidated"
  expect_error(patient_reference_from_data(bad), "Sabit hasta referansı")
  bad <- data; bad$cells$USP9X[1] <- NA_real_
  expect_error(patient_reference_from_data(bad), "USP9X")
  bad <- data; bad$metadata$data_version <- "unknown"
  expect_error(patient_reference_from_data(bad), "sürümü")
  bad <- data; bad$cells$patient_id[1] <- NA_character_
  expect_error(patient_reference_from_data(bad), "Sabit hasta referansı")
  bad <- data; bad$cells$cell_id[2] <- bad$cells$cell_id[1]
  expect_error(patient_reference_from_data(bad), "Sabit hasta referansı")
})

test_that("scores do not depend on external data, subtype risk weights or model confidence", {
  data <- load_stoplaris_data(file.path(app_root, "data"))
  expected <- patient_reference_from_data(data)$table
  changed <- data
  changed$cells$USP9X[changed$cells$dataset != "GSE173278"] <- 999
  changed$cells$predicted_label <- "unrelated_prediction"
  changed$cells$max_probability <- 0
  changed$cells$cell_type <- "no_risk_weight"
  expect_equal(patient_reference_from_data(changed)$table, expected)
})

test_that("patient CSV report retains method provenance and does not invent clinical risk", {
  ref <- patient_reference_from_data(load_stoplaris_data(file.path(app_root, "data")))
  report <- patient_profile_export(ref, "JK126")
  expect_identical(report$clinical_risk_available, FALSE)
  expect_true(is.na(report$clinical_risk_probability))
  expect_identical(report$method_version, PATIENT_PROFILE_METHOD)
  expect_equal(report$reference_n_cells, 842L)
  expect_equal(report$reference_n_patients, 10L)
  expect_true(report$reference_includes_selected_patient)
  expect_match(report$formula, "average_rank", fixed = TRUE)
  expect_match(report$reference_cells_sha256, "^[a-f0-9]{64}$")
})

test_that("server keeps original reference when unrelated exploration filters change", {
  data <- load_stoplaris_data(file.path(app_root, "data"))
  shiny::testServer(function(input, output, session) {
    profile <- patient_assessment_server(input, output, session, data)
  }, {
    session$setInputs(patient_profile_id = "JK126")
    expect_equal(profile$selected_profile()$summary$n_cells, 6L)
    expect_equal(profile$selected_profile()$summary$score_0_10, 10)
    expect_match(output$patient_profile_score$html, "Klinik risk: hesaplanamıyor", fixed = TRUE)
    expect_match(output$patient_profile_score$html, "6 hücre", fixed = TRUE)
    session$setInputs(explorer_dataset = "GSE97930", explorer_patient = "unknown", explorer_range = c(0, 0))
    expect_equal(profile$selected_profile()$summary$score_0_10, 10)
    expect_equal(profile$reference$reference_n_patients, 10L)
    session$setInputs(patient_profile_id = "JK152")
    expect_equal(profile$selected_profile()$summary$score_0_10, 0)
    expect_match(output$patient_profile_method$html, "sıfır klinik risk anlamına gelmez", fixed = TRUE)
  })
})
