library(testthat)
app_root <- Sys.getenv("STOPLARIS_TEST_ROOT", normalizePath(".."))
source(file.path(app_root, "R", "data.R"), local = FALSE)

test_that("real cohorts and expression records are complete", {
  d <- load_stoplaris_data(file.path(app_root, "data"))
  expect_equal(sum(d$cells$dataset == "GSE173278"), 842L)
  expect_equal(sum(d$cells$dataset == "GSE141946"), 1404L)
  expect_equal(sum(d$cells$dataset == "GSE97930"), 10253L)
  main <- d$cells[d$cells$dataset == "GSE173278", ]
  expect_equal(length(unique(main$patient_id)), 10L)
  expect_equal(nrow(unique(main[c("dataset", "cell_id")])), 842L)
  expect_equal(sum(complete.cases(main[c("umap_1", "umap_2")])) ,842L)
  healthy <- d$cells[d$cells$dataset == "GSE97930", ]
  expect_equal(sum(healthy$USP9X > 0, na.rm = TRUE), 809L)
  expect_true(all(is.na(healthy$patient_id)))
  ext <- d$cells[d$cells$dataset == "GSE141946", ]
  expect_equal(length(unique(na.omit(ext$patient_id))), 3L)
  expect_true(all(c("expanded_grid", "calibrated") %in% d$metrics$stage))
})

test_that("confusion matrices preserve sample totals and class identity", {
  d <- load_stoplaris_data(file.path(app_root, "data"))
  for (stage in c("expanded_grid", "calibrated")) {
    cm <- d$confusion[d$confusion$stage == stage, ]
    expect_equal(sum(cm$n), 842)
    truth_counts <- aggregate(n ~ true_label, cm, sum)
    expected <- c(iCAF_like_uncertain = 37, myCAF_like = 188, pericyte_vCAF_like = 617)
    expect_equal(truth_counts$n, unname(expected[truth_counts$true_label]))
    expect_equal(sum(cm$n[cm$true_label == cm$predicted_label]), 789)
  }
})

test_that("uploaded data does not inherit project validation", {
  d <- load_stoplaris_data(file.path(app_root, "data"))$cells[1:3, ]
  clean <- validate_cells(d, uploaded = TRUE)
  expect_true(all(clean$prediction_type == "user_supplied_unvalidated"))
  expect_error(validate_cells(d[, setdiff(names(d), "USP9X")]), "Eksik")
  duplicate <- rbind(d, d[1, ])
  expect_error(validate_cells(duplicate), "tekrarlanan")
  bad <- d; bad$USP9X[1] <- "abc"
  expect_error(validate_cells(bad), "sonlu")
  bad <- d; bad$USP9X[1] <- Inf
  expect_error(validate_cells(bad), "sonlu")
  bad <- d; bad$USP9X[1] <- -1
  expect_error(validate_cells(bad), "negatif")
  bad <- d; bad$cell_id[1] <- NA
  expect_error(validate_cells(bad), "boş")
  expect_error(validate_cells(d[FALSE, ]), "en az")
  bad <- d; bad$stromal_fibroblast_ecm_z[1] <- "not_a_score"
  expect_error(validate_cells(bad), "sonlu")
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  utils::write.csv(d[, setdiff(names(d), "patient_id")], path, row.names = FALSE)
  expect_true(all(is.na(read_uploaded_cells(path)$patient_id)))
})

test_that("CSV exports preserve data and neutralize textual formulas", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  input <- data.frame(label = c("=1+1", " +CMD", "@bad", "normal", NA), score = c(-1, 0, 1, 2, NA))
  safe_export_csv(input, path)
  got <- stoplaris_read_csv(path)
  expect_equal(got$label[1:3], paste0("'", input$label[1:3]))
  expect_equal(got$score, input$score)
  expect_equal(got$label[4], "normal")
})
