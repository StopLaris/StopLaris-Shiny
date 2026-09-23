# Descriptive patient module; it never estimates clinical risk or runs a model.
# Integration: source after R/data.R; include patient_assessment_ui() in tabsetPanel;
# call patient_assessment_server(input, output, session, data) ONCE with the original
# load_stoplaris_data() list, never a reactive/uploaded/filter-dependent cells table.
# All input/output IDs use patient_profile_ to avoid the existing explorer filters.
# Testable API: patient_rank_index(), patient_reference_from_data(),
# patient_profile_summary(reference, patient_id), patient_profile_export().

PATIENT_PROFILE_METHOD <- "USP9X_cohort_midrank_0_10_v1"
PATIENT_PROFILE_VERSION <- "V5_STAGE2_2026-09-20"
PATIENT_PROFILE_DATASET <- "GSE173278"

patient_rank_index <- function(patient_means) {
  if (!is.numeric(patient_means) || length(patient_means) < 2L ||
      any(!is.finite(patient_means)) || any(patient_means < 0))
    stop("İndeks için en az iki sonlu, negatif olmayan hasta ortalaması gerekir.", call. = FALSE)
  n <- length(patient_means)
  ranks <- rank(patient_means, ties.method = "average")
  data.frame(reference_rank = ranks, score_0_10 = 10 * (ranks - 1) / (n - 1))
}

patient_reference_from_data <- function(data) {
  if (!is.list(data) || !is.data.frame(data$cells) ||
      !identical(data$metadata$data_version, PATIENT_PROFILE_VERSION))
    stop("Hasta indeksi yalnızca sürümü doğrulanmış sabit proje referansında kullanılabilir.", call. = FALSE)
  required <- c("dataset", "cell_id", "patient_id", "sample_id", "cell_type", "USP9X", "prediction_type")
  if (!all(required %in% names(data$cells))) stop("Hasta referansında gerekli kaynak alanları eksik.", call. = FALSE)
  cells <- data$cells[data$cells$dataset %in% PATIENT_PROFILE_DATASET, , drop = FALSE]
  source <- Filter(function(x) identical(x$id, PATIENT_PROFILE_DATASET), data$metadata$datasets)
  if (length(source) != 1L || !isTRUE(source[[1]]$patient_ids_verified))
    stop("Kaynak hasta kimlikleri doğrulanmamış.", call. = FALSE)
  if (nrow(cells) != source[[1]]$n_cells || nrow(cells) < 2L ||
      anyNA(cells$patient_id) || any(!nzchar(cells$patient_id)) ||
      length(unique(cells$patient_id)) != source[[1]]$n_patients ||
      anyDuplicated(cells$cell_id) || anyNA(cells$sample_id) || any(!nzchar(cells$sample_id)) ||
      !all(cells$prediction_type %in% "OOF_leave_one_patient_out"))
    stop("Sabit hasta referansı eksik veya uygun değil; filtrelenmiş ya da yüklenmiş veriden indeks hesaplanmaz.", call. = FALSE)
  if (!is.numeric(cells$USP9X) || any(!is.finite(cells$USP9X)) || any(cells$USP9X < 0))
    stop("Sabit referanstaki USP9X değerleri eksik veya geçersiz; sessizce hücre çıkarılmaz.", call. = FALSE)
  groups <- split(cells, as.character(cells$patient_id))
  table <- do.call(rbind, lapply(groups, function(d) {
    data.frame(patient_id = as.character(d$patient_id[[1]]), n_cells = nrow(d),
      n_samples = length(unique(d$sample_id)), mean_USP9X = mean(d$USP9X),
      median_USP9X = stats::median(d$USP9X), USP9X_positive_n = sum(d$USP9X > 0),
      USP9X_positive_fraction = mean(d$USP9X > 0),
      sample_ids = paste(sort(unique(d$sample_id)), collapse = "; "),
      source_contexts = if ("reg_stg" %in% names(d)) paste(sort(unique(na.omit(d$reg_stg))), collapse = "; ") else "",
      stringsAsFactors = FALSE)
  }))
  rownames(table) <- NULL
  table <- cbind(table, patient_rank_index(table$mean_USP9X))
  source_records <- data$provenance$sources
  evidence_names <- grep("(source_metadata|caf_USP9X_cell_values)\\.csv$", names(source_records), value = TRUE)
  list(cells = cells, table = table, dataset = PATIENT_PROFILE_DATASET,
       data_version = PATIENT_PROFILE_VERSION, method = PATIENT_PROFILE_METHOD,
       reference_n_patients = nrow(table), reference_n_cells = nrow(cells),
       usp9x_denominator = source[[1]]$usp9x_denominator,
       source_hashes = source_records[evidence_names],
       packaged_cells_sha256 = data$provenance$outputs_sha256[["cells.csv"]],
       clinical_risk_available = FALSE)
}

patient_profile_summary <- function(reference, patient_id) {
  if (length(patient_id) != 1L || is.na(patient_id) || !patient_id %in% reference$table$patient_id)
    stop("Hasta kimliği sabit GSE173278 referansında bulunmuyor.", call. = FALSE)
  selected <- reference$table[reference$table$patient_id == patient_id, , drop = FALSE]
  d <- reference$cells[reference$cells$patient_id == patient_id, , drop = FALSE]
  labels <- sort(unique(reference$cells$cell_type))
  subtype <- do.call(rbind, lapply(labels, function(label) {
    x <- d[d$cell_type == label, , drop = FALSE]
    data.frame(cell_type = label, n_cells = nrow(x), cell_fraction = nrow(x) / nrow(d),
      mean_USP9X = if (nrow(x)) mean(x$USP9X) else NA_real_,
      USP9X_positive_n = if (nrow(x)) sum(x$USP9X > 0) else NA_integer_,
      stringsAsFactors = FALSE)
  }))
  list(summary = selected, cells = d, subtype = subtype)
}

patient_profile_export <- function(reference, patient_id) {
  x <- patient_profile_summary(reference, patient_id)$summary
  x$dataset <- reference$dataset
  x$method_version <- reference$method
  x$data_version <- reference$data_version
  x$reference_n_patients <- reference$reference_n_patients
  x$reference_n_cells <- reference$reference_n_cells
  x$normalization <- "log1p(10000 * USP9X raw count / source library count)"
  x$normalization_denominator <- reference$usp9x_denominator
  x$formula <- "10 * (average_rank(patient_mean_USP9X) - 1) / (reference_n_patients - 1)"
  x$reference_includes_selected_patient <- TRUE
  x$clinical_risk_available <- FALSE
  x$clinical_risk_probability <- NA_real_
  x$clinical_risk_reason <- "No linked clinical outcome labels or validated recurrence/survival risk model in the package."
  x$interpretation <- "Within-cohort relative expression rank; 0/10 and 10/10 are not clinical risk endpoints."
  x$reference_cells_sha256 <- if (is.null(reference$packaged_cells_sha256)) NA_character_ else reference$packaged_cells_sha256
  x
}

patient_assessment_ui <- function() {
  shiny::tabPanel("Hasta değerlendirmesi", value = "patient",
    shiny::div(class = "section-intro", shiny::div(class = "eyebrow", "GSE173278 · SABİT ARAŞTIRMA REFERANSI"),
      shiny::h2("Hasta düzeyinde USP9X profili"),
      shiny::p("Mevcut on araştırma hastasını, aynı veri kümesindeki göreli ifade düzeyiyle inceleyin. Bu bölüm bir klinik risk modeli değildir.")),
    shiny::div(class = "control-row", shiny::selectInput("patient_profile_id", "Araştırma hastası", choices = NULL)),
    shiny::uiOutput("patient_profile_score"),
    shiny::div(class = "two-col",
      shiny::tags$section(class = "sl-card", shiny::div(class = "card-heading", shiny::h3("Sabit hasta referansı"),
        shiny::p(class = "muted", "Noktalar hasta ortalamalarıdır. Parantez içindeki n, analizdeki hücre sayısıdır.")),
        shiny::plotOutput("patient_profile_reference_plot", height = "350px")),
      shiny::tags$section(class = "sl-card", shiny::div(class = "card-heading", shiny::h3("Bu hastanın hücre bileşimi")),
        shiny::div(class = "patient-table-scroll", shiny::tableOutput("patient_profile_subtypes")),
        shiny::p(class = "fine-print", "Alt tipler kaynak etiketleridir; bu sınıflara risk ağırlığı atanmaz. Hücre olmayan sınıfların ortalaması hesaplanmaz."))),
    shiny::tags$section(class = "sl-card", shiny::div(class = "card-heading", shiny::h3("İndeks nasıl hesaplanır?")),
      shiny::uiOutput("patient_profile_method"), shiny::downloadButton("patient_profile_download", "Hasta profili · CSV"))
  )
}

patient_assessment_server <- function(input, output, session, data) {
  # Compute once from injected original data; no dependency on exploration filters.
  reference <- patient_reference_from_data(data)
  fmt <- function(x, digits = 2L) formatC(x, digits = digits, format = "f", decimal.mark = ",")
  shiny::observeEvent(TRUE, {
    shiny::updateSelectInput(session, "patient_profile_id", choices = reference$table$patient_id,
      selected = reference$table$patient_id[[1]])
  }, once = TRUE)
  selected_profile <- shiny::reactive({
    id <- input$patient_profile_id
    if (is.null(id) || !length(id)) id <- reference$table$patient_id[[1]]
    patient_profile_summary(reference, id)
  })
  output$patient_profile_score <- shiny::renderUI({
    x <- selected_profile()$summary
    shiny::tagList(
      shiny::div(class = "note-box", shiny::strong("Klinik risk: hesaplanamıyor. "),
        "Nüks/sağkalım sonlanımı ve doğrulanmış risk modeli bulunmuyor."),
      shiny::div(class = "kpi-grid",
        shiny::div(class = "kpi-card accent", shiny::div(class = "kpi-label", "USP9X GÖRELİ İFADE İNDEKSİ"),
          shiny::div(class = "kpi-value", paste0(fmt(x$score_0_10, 1), " / 10")),
          shiny::div(class = "kpi-caption", "Klinik risk veya olasılık değildir")),
        shiny::div(class = "kpi-card", shiny::div(class = "kpi-label", "REFERANS SIRASI"),
          shiny::div(class = "kpi-value", paste0(fmt(x$reference_rank, 0), " / ", reference$reference_n_patients)),
          shiny::div(class = "kpi-caption", "Düşükten yükseğe ortalama ifade")),
        shiny::div(class = "kpi-card", shiny::div(class = "kpi-label", "HÜCRE / KAYNAK ÖRNEK"),
          shiny::div(class = "kpi-value", paste0(x$n_cells, " / ", x$n_samples)),
          shiny::div(class = "kpi-caption", "Seçili hastanın analize alınan hücreleri")),
        shiny::div(class = "kpi-card", shiny::div(class = "kpi-label", "ORTALAMA USP9X"),
          shiny::div(class = "kpi-value", fmt(x$mean_USP9X, 3)),
          shiny::div(class = "kpi-caption", paste0("log1p(CP10K) · ", x$USP9X_positive_n, "/", x$n_cells, " pozitif hücre")))),
      shiny::div(class = "note-box", shiny::strong(paste0("Veri desteği: ", x$n_cells, " hücre ve ", x$n_samples, " kaynak örnek. ")),
        "Referanstaki hasta başına hücre sayısı ", min(reference$table$n_cells), "–", max(reference$table$n_cells),
        " aralığındadır. Az hücreli ortalamalar sınırlı örneklemle temsil edilir; indeks örnekleme belirsizliğini ölçmez. Hücre ve örnek bileşimi sıralamayı etkileyebilir.")
    )
  })
  output$patient_profile_reference_plot <- shiny::renderPlot({
    selected <- selected_profile()$summary$patient_id
    d <- reference$table
    d$label <- paste0(d$patient_id, " (n=", d$n_cells, ")")
    d$label <- factor(d$label, levels = d$label[order(d$mean_USP9X)])
    d$selected <- d$patient_id == selected
    ggplot2::ggplot(d, ggplot2::aes(x = mean_USP9X, y = label, colour = selected)) +
      ggplot2::geom_point(size = 3.5) +
      ggplot2::scale_colour_manual(values = c("FALSE" = "#96929A", "TRUE" = "#BD1F36")) +
      ggplot2::labs(x = "Hasta ortalama USP9X · log1p(CP10K)", y = NULL) +
      sl_theme() + ggplot2::theme(legend.position = "none", panel.grid.minor = ggplot2::element_blank())
  }, res = 100)
  output$patient_profile_subtypes <- shiny::renderTable({
    d <- selected_profile()$subtype
    data.frame("Kaynak hücre etiketi" = d$cell_type, "Hücre" = d$n_cells,
      "Pay (%)" = round(100 * d$cell_fraction, 1), "Ort. USP9X" = round(d$mean_USP9X, 4),
      "USP9X > 0" = d$USP9X_positive_n, check.names = FALSE)
  }, striped = TRUE, bordered = FALSE, spacing = "s", na = "—", digits = 4)
  output$patient_profile_method <- shiny::renderUI({
    x <- selected_profile()$summary
    shiny::tagList(
      shiny::p("1. Her hastanın kaynak paketteki seçilmiş hücrelerinin log-normalize USP9X değerleri aritmetik olarak ortalanır. Hücreler hasta içinde eşit ağırlıklıdır; sıralamada her hasta tek bir ortalamayla temsil edilir."),
      shiny::p("2. Sabit GSE173278 referansındaki ", reference$reference_n_patients, " ortalama düşükten yükseğe sıralanır. Eşit ortalamalara ortalama sıra verilir."),
      shiny::p(shiny::tags$code("İndeks = 10 × (ortalama sıra − 1) / (referans hasta sayısı − 1)")),
      shiny::p("Bu seçim: 10 × (", fmt(x$reference_rank, 2), " − 1) / (", reference$reference_n_patients,
        " − 1) = ", fmt(x$score_0_10, 3), ". Referans seçili hastayı da içerir; bu dış örneklem performans testi değildir."),
      shiny::p(shiny::strong("10/10"), " yalnızca bu referanstaki en büyük ortalamayı; ", shiny::strong("0/10"),
        " en küçük ortalamayı gösterir. %100 risk veya sıfır klinik risk anlamına gelmez. İndeks göreli sıralamadır; ifade farkının büyüklüğü değildir. Tüm ortalamalar eşitse değer 5 olur."),
      shiny::p("Normalizasyon paydası: ", reference$usp9x_denominator),
      shiny::p("Hücreler kaynak pakette seçilmiş CAF/stromal adaylarıdır; bütün tümörü temsil etmez. Kayıtlı birden çok doku/örnek bağlamı hasta içinde birlikte özetlenir; bu bir zaman noktası veya nüks tahmini değildir."),
      shiny::p(class = "fine-print", "Kaynak örnekleri: ", x$sample_ids, " · Kaynak bağlam kodları: ", x$source_contexts),
      shiny::p(class = "fine-print", "Yöntem: ", reference$method, " · Veri sürümü: ", reference$data_version,
        " · Sabit referans: ", reference$reference_n_patients, " hasta / ", reference$reference_n_cells,
        " hücre. Keşif filtreleri, dış/sağlıklı kohort ve kullanıcı yüklemeleri bu referansı değiştirmez.")
    )
  })
  output$patient_profile_download <- shiny::downloadHandler(
    filename = function() paste0("StopLaris_", selected_profile()$summary$patient_id, "_molekuler_profil.csv"),
    content = function(file) {
      result <- patient_profile_export(reference, selected_profile()$summary$patient_id)
      if (exists("safe_export_csv", mode = "function")) safe_export_csv(result, file)
      else utils::write.csv(result, file, row.names = FALSE, na = "", fileEncoding = "UTF-8")
    }, contentType = "text/csv;charset=utf-8")
  invisible(list(reference = reference, selected_profile = selected_profile))
}
