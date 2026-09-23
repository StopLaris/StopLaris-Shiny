# StopLaris research explorer: local data loading and explicit schema validation.
stoplaris_read_csv <- function(path) {
  if (!file.exists(path)) stop(sprintf("Veri dosyası bulunamadı: %s", basename(path)), call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
                  na.strings = c("", "NA"), fileEncoding = "UTF-8")
}

validate_cells <- function(cells, uploaded = FALSE) {
  if (!is.data.frame(cells)) stop("Hücre verisi bir tablo olmalıdır.", call. = FALSE)
  if (anyDuplicated(names(cells))) stop("Sütun adları benzersiz olmalıdır.", call. = FALSE)
  required <- c("dataset", "cell_id", "patient_id", "cell_type", "USP9X")
  missing <- setdiff(required, names(cells))
  if (length(missing)) stop(paste("Eksik zorunlu sütunlar:", paste(missing, collapse = ", ")), call. = FALSE)
  if (!nrow(cells)) stop("Dosyada en az bir hücre satırı bulunmalıdır.", call. = FALSE)
  if (nrow(cells) > 500000L) stop("Bu prototip tek dosyada en fazla 500.000 hücre kabul eder.", call. = FALSE)
  for (column in c("dataset", "cell_id", "cell_type")) {
    cells[[column]] <- as.character(cells[[column]])
    if (anyNA(cells[[column]]) || any(!nzchar(trimws(cells[[column]]))))
      stop(paste(column, "sütunu boş değer içeremez."), call. = FALSE)
  }
  cells$patient_id <- as.character(cells$patient_id)
  cells$patient_id[!is.na(cells$patient_id) & !nzchar(trimws(cells$patient_id))] <- NA_character_
  if (anyDuplicated(cells[c("dataset", "cell_id")]))
    stop("Aynı veri seti içinde tekrarlanan cell_id bulundu.", call. = FALSE)
  numeric_cols <- intersect(c("USP9X", "USP9X_raw", "USP9X_raw_counts", "umap_1", "umap_2", "FibroScore1",
      "inflammatory_iCAF_z", "contractile_myCAF_z", "stromal_perivascular_z",
      grep("^(score_|prob_|p_)|_z$|_counts$", names(cells), value = TRUE)), names(cells))
  for (column in numeric_cols) {
    value <- cells[[column]]
    converted <- suppressWarnings(as.numeric(value))
    if (any(!is.na(value) & is.na(converted)) || any(!is.na(converted) & !is.finite(converted)))
      stop(paste(column, "yalnızca sonlu sayılar veya boş değerler içermelidir."), call. = FALSE)
    cells[[column]] <- converted
  }
  if (any(cells$USP9X < 0, na.rm = TRUE)) stop("USP9X ekspresyonu negatif olamaz.", call. = FALSE)
  for (column in intersect(c("umap_1", "umap_2"), names(cells))) {
    if (!all(c("umap_1", "umap_2") %in% names(cells)))
      stop("UMAP için umap_1 ve umap_2 birlikte verilmelidir.", call. = FALSE)
  }
  if (all(c("umap_1", "umap_2") %in% names(cells)) &&
      any(xor(is.na(cells$umap_1), is.na(cells$umap_2))))
    stop("Bir hücrenin iki UMAP koordinatı birlikte dolu veya birlikte boş olmalıdır.", call. = FALSE)
  if (uploaded) {
    # User-provided labels/predictions cannot inherit project validation evidence.
    cells$source_origin <- "Kullanıcı yüklemesi; doğrulanmış proje paketi dışında"
    cells$prediction_type <- "user_supplied_unvalidated"
  }
  cells
}

read_uploaded_cells <- function(path) {
  if (!file.exists(path)) stop("Yüklenen dosya okunamadı.", call. = FALSE)
  if (file.info(path)$size > 50 * 1024^2) stop("CSV dosyası en fazla 50 MB olabilir.", call. = FALSE)
  data <- stoplaris_read_csv(path)
  if (!"patient_id" %in% names(data)) data$patient_id <- NA_character_
  validate_cells(data, uploaded = TRUE)
}

safe_export_csv <- function(data, path) {
  # Prevent spreadsheet formula execution in textual identifiers, preserve numbers.
  clean <- data
  for (column in names(clean)) {
    if (is.factor(clean[[column]])) clean[[column]] <- as.character(clean[[column]])
    if (is.character(clean[[column]])) {
      idx <- !is.na(clean[[column]]) & grepl("^[[:space:]]*[=+@-]", clean[[column]])
      clean[[column]][idx] <- paste0("'", clean[[column]][idx])
    }
  }
  utils::write.csv(clean, path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  invisible(path)
}

load_stoplaris_data <- function(data_dir = "data") {
  required <- c("cells.csv", "metrics.csv", "per_patient_metrics.csv", "confusion.csv", "provenance.json")
  missing <- required[!file.exists(file.path(data_dir, required))]
  if (length(missing)) stop(paste("Paket eksik; ZIP dosyasının tamamını çıkarın:", paste(missing, collapse = ", ")), call. = FALSE)
  cells <- validate_cells(stoplaris_read_csv(file.path(data_dir, "cells.csv")))
  provenance <- jsonlite::read_json(file.path(data_dir, "provenance.json"), simplifyVector = FALSE)
  metadata_path <- file.path(data_dir, "metadata.json")
  metadata <- if (file.exists(metadata_path)) jsonlite::read_json(metadata_path, simplifyVector = FALSE) else provenance
  read_optional <- function(name) {
    p <- file.path(data_dir, name)
    if (file.exists(p)) stoplaris_read_csv(p) else data.frame()
  }
  external_file <- file.path(data_dir, "external_summary.json")
  external <- if (file.exists(external_file)) jsonlite::read_json(external_file, simplifyVector = FALSE) else list()
  permutation_file <- file.path(data_dir, "permutation_status.json")
  permutation <- if (file.exists(permutation_file)) jsonlite::read_json(permutation_file, simplifyVector = FALSE) else list()
  patient <- stoplaris_read_csv(file.path(data_dir, "per_patient_metrics.csv"))
  list(cells = cells, metrics = stoplaris_read_csv(file.path(data_dir, "metrics.csv")),
       per_patient_metrics = patient, patient_predictions = patient,
       confusion = stoplaris_read_csv(file.path(data_dir, "confusion.csv")),
       metadata = metadata, provenance = provenance, external_summary = external,
       permutation_status = permutation, healthy_summary = read_optional("healthy_summary.csv"),
       marker_summary = read_optional("marker_summary.csv"), reliability_bins = read_optional("reliability_bins.csv"),
       permutation_scores = read_optional("permutation_scores.csv"),
       sources = read_optional("sources.csv"), feature_importance = read_optional("feature_importance.csv"),
       notes = if (file.exists(file.path(data_dir, "scientific_notes.md")))
         paste(readLines(file.path(data_dir, "scientific_notes.md"), warn = FALSE, encoding = "UTF-8"), collapse = "\n") else "")
}
