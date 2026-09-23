# All calculations in this file are descriptive views over the packaged records.
# Validation metrics always use the packaged results, never uploaded cell records.
sl_format <- function(x, digits = 3L) {
  if (!length(x) || is.na(x[[1]]) || !is.finite(as.numeric(x[[1]]))) return("—")
  format(round(as.numeric(x[[1]]), digits), nsmall = digits, big.mark = ".", decimal.mark = ",", scientific = FALSE, trim = TRUE)
}
sl_n <- function(x) sl_format(x, 0L)
sl_unique_n <- function(x) length(unique(x[!is.na(x) & nzchar(as.character(x))]))
sl_value <- function(x, fallback) if (is.null(x) || !length(x)) fallback else x
sl_kpi <- function(label, value, caption, accent = FALSE) {
  shiny::div(class = paste("kpi-card", if (accent) "accent"), shiny::div(class = "kpi-label", label),
    shiny::div(class = "kpi-value", value), shiny::div(class = "kpi-caption", caption))
}
sl_theme <- function() {
  ggplot2::theme_minimal(base_size = 11, base_family = "sans") +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(colour = "#ECE9EC", linewidth = .35),
      axis.title = ggplot2::element_text(colour = "#64646D", size = 10),
      axis.text = ggplot2::element_text(colour = "#5F5F68", size = 9),
      plot.title = ggplot2::element_text(face = "bold", size = 12, colour = "#292A2F"),
      plot.subtitle = ggplot2::element_text(size = 10, colour = "#707078"),
      legend.title = ggplot2::element_blank(), legend.text = ggplot2::element_text(size = 8, colour = "#5F5F68"),
      legend.position = "bottom", plot.margin = ggplot2::margin(10, 16, 7, 7))
}
sl_palette <- function(n) rep(c("#BD1F36", "#677480", "#D3A667", "#C36C7B", "#9690A5", "#9D7565", "#49525C", "#D6B2B8"), length.out = n)
sl_table <- function(df, page_length = 8L, search = TRUE, digits = 4L) {
  table <- DT::datatable(df, rownames = FALSE, escape = TRUE,
    class = if (ncol(df) > 3L) "display" else "display sl-narrow-table",
    options = list(pageLength = page_length, lengthMenu = c(8, 15, 30, 50), scrollX = ncol(df) > 3L,
      searching = search, autoWidth = TRUE,
      language = list(search = "Ara:", lengthMenu = "_MENU_ satır", info = "_TOTAL_ kayıttan _START_–_END_",
        infoEmpty = "Kayıt yok", zeroRecords = "Eşleşen kayıt bulunamadı", emptyTable = "Bu seçim için kayıt yok",
        infoFiltered = "(toplam _MAX_ kayıt)", paginate = list(previous = "Önceki", "next" = "Sonraki"))))
  numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
  if (length(numeric_cols)) table <- DT::formatRound(table, columns = numeric_cols, digits = digits, mark = ".", dec.mark = ",")
  table
}

app_server <- function(input, output, session, data = load_stoplaris_data("data")) {
  patient_assessment_server(input, output, session, data)
  metadata <- sl_value(data$metadata, list())
  stages <- sl_value(metadata$stages, list(main = "expanded_grid", secondary = "calibrated", external = "external_transfer"))
  main_stage <- sl_value(stages$main, "expanded_grid")
  secondary_stage <- sl_value(stages$secondary, "calibrated")
  external_stage <- sl_value(stages$external, "external_transfer")
  all_cells <- data$cells
  main_cells <- all_cells[all_cells$prediction_type %in% "OOF_leave_one_patient_out", , drop = FALSE]
  if (!nrow(main_cells)) main_cells <- all_cells[all_cells$dataset %in% "GSE173278", , drop = FALSE]
  external_cells <- all_cells[all_cells$prediction_type %in% "frozen_external_transfer", , drop = FALSE]
  if (!nrow(external_cells)) external_cells <- all_cells[all_cells$dataset %in% "GSE141946", , drop = FALSE]
  healthy_cells <- all_cells[all_cells$dataset %in% "GSE97930", , drop = FALSE]
  dataset_metadata <- sl_value(metadata$datasets, list())
  dataset_ids <- unique(all_cells$dataset)
  label_for_dataset <- function(id) {
    for (item in dataset_metadata) if (is.list(item) && identical(item$id, id)) return(sl_value(item$label, id))
    id
  }
  dataset_choices <- stats::setNames(dataset_ids, vapply(dataset_ids, label_for_dataset, character(1)))
  stage_labels <- c("V5 ana · kalibrasyonsuz OOF", "V5 ikincil · kalibre edilmiş OOF")
  stage_choices <- stats::setNames(c(main_stage, secondary_stage), stage_labels)
  stage_choices <- stage_choices[stage_choices %in% unique(data$metrics$stage)]
  uploaded <- shiny::reactiveVal(NULL)
  upload_message <- shiny::reactiveVal(NULL)
  upload_error <- shiny::reactiveVal(FALSE)
  uploaded_choice <- "__uploaded__"

  metric_rows <- function(stage) data$metrics[data$metrics$stage %in% stage, , drop = FALSE]
  metric_value <- function(stage, pattern, aggregation = NULL) {
    m <- metric_rows(stage)
    if (!nrow(m) || !all(c("metric", "value") %in% names(m))) return(NA_real_)
    idx <- grepl(pattern, m$metric, ignore.case = TRUE)
    if (!is.null(aggregation) && "aggregation" %in% names(m)) idx <- idx & grepl(aggregation, m$aggregation, ignore.case = TRUE)
    result <- as.numeric(m$value[idx])
    if (length(result)) result[[1]] else NA_real_
  }
  main_patient_f1 <- function(stage = main_stage) {
    p <- data$per_patient_metrics[data$per_patient_metrics$stage %in% stage, , drop = FALSE]
    if (nrow(p) && "macro_f1_present_true_classes" %in% names(p)) return(mean(p$macro_f1_present_true_classes, na.rm = TRUE))
    metric_value(stage, "macro.*f1|f1.*macro", "patient")
  }
  patient_rows <- function(stage) data$per_patient_metrics[data$per_patient_metrics$stage %in% stage, , drop = FALSE]
  numeric_scores <- function(d) {
    is_upload <- "prediction_type" %in% names(d) && any(d$prediction_type %in% "user_supplied_unvalidated")
    if (!is_upload) {
      score_names <- vapply(sl_value(metadata$score_columns, list()), function(item) item$name, character(1))
      candidates <- intersect(c("USP9X", score_names), names(d))
      return(candidates[vapply(candidates, function(nm) is.numeric(d[[nm]]) && any(is.finite(d[[nm]])), logical(1))])
    }
    reserved <- c("USP9X_raw_counts", "USP9X_raw", "USP9X_positive", "umap_1", "umap_2", "library_size", "library_counts", "n_genes", "n_features", "percent_mt", "max_probability", "n_counts", "nCount_RNA", "nFeature_RNA")
    candidates <- names(d)[vapply(d, is.numeric, logical(1))]
    candidates <- candidates[!candidates %in% reserved & !grepl("^(p_|prob_)", candidates)]
    candidates[vapply(candidates, function(nm) any(is.finite(d[[nm]])), logical(1))]
  }
  score_label <- function(nm) {
    if (identical(nm, "USP9X")) return("USP9X · log1p(CP10K)")
    for (item in sl_value(metadata$score_columns, list())) {
      if (is.list(item) && identical(item$name, nm)) return(paste0(nm, if (!identical(sl_value(item$label, nm), nm)) paste0(" · ", item$label) else ""))
    }
    nm
  }

  shiny::observe({
    choices <- dataset_choices
    if (!is.null(uploaded())) choices <- c(choices, "Kullanıcı yüklemesi · doğrulanmamış" = uploaded_choice)
    previous <- shiny::isolate(input$explorer_dataset)
    selected <- if (!is.null(previous) && previous %in% choices) previous else if (nrow(main_cells)) main_cells$dataset[[1]] else dataset_ids[[1]]
    shiny::updateSelectInput(session, "explorer_dataset", choices = choices, selected = selected)
  })
  shiny::observeEvent(TRUE, {
    shiny::updateSelectInput(session, "model_stage", choices = stage_choices, selected = main_stage)
  }, once = TRUE)

  dataset_cells <- shiny::reactive({
    selected <- sl_value(input$explorer_dataset, if (nrow(main_cells)) main_cells$dataset[[1]] else dataset_ids[[1]])
    if (identical(selected, uploaded_choice)) {
      shiny::req(uploaded())
      return(uploaded())
    }
    all_cells[all_cells$dataset %in% selected, , drop = FALSE]
  })
  output$patient_filter_ui <- shiny::renderUI({
    d <- dataset_cells()
    ids <- sort(unique(d$patient_id[!is.na(d$patient_id) & nzchar(d$patient_id)]))
    if (!length(ids)) return(shiny::div(class = "fine-print", "Bu kaynakta doğrulanmış hasta / donör kimliği bulunmuyor."))
    shiny::selectInput("explorer_patient", "Hasta / donör", choices = c("Tümü" = "__all__", stats::setNames(ids, ids)), selected = "__all__")
  })
  shiny::observeEvent(dataset_cells(), {
    d <- dataset_cells()
    types <- sort(unique(d$cell_type[!is.na(d$cell_type)]))
    shiny::updateSelectInput(session, "explorer_cell_type", choices = c("Tümü" = "__all__", stats::setNames(types, types)), selected = "__all__")
    features <- numeric_scores(d)
    if (!length(features)) features <- "USP9X"
    features <- c(intersect("USP9X", features), setdiff(features, "USP9X"))
    shiny::updateSelectInput(session, "explorer_feature", choices = stats::setNames(features, vapply(features, score_label, character(1))), selected = features[[1]])
    values <- d$USP9X[is.finite(d$USP9X)]
    limits <- if (length(values)) range(values) else c(0, 1)
    if (diff(limits) == 0) limits[[2]] <- limits[[1]] + 1
    shiny::updateSliderInput(session, "explorer_range", min = floor(limits[[1]] * 100) / 100,
      max = ceiling(limits[[2]] * 100) / 100, value = c(floor(limits[[1]] * 100) / 100, ceiling(limits[[2]] * 100) / 100))
    groups <- c("Hücre etiketi" = "cell_type")
    if (any(!is.na(d$patient_id) & nzchar(d$patient_id))) groups <- c(groups, "Hasta / donör" = "patient_id")
    shiny::updateSelectInput(session, "explorer_group", choices = groups, selected = "cell_type")
  }, ignoreInit = FALSE)
  shiny::observeEvent(input$reset_filters, {
    d <- dataset_cells()
    shiny::updateSelectInput(session, "explorer_patient", selected = "__all__")
    shiny::updateSelectInput(session, "explorer_cell_type", selected = "__all__")
    values <- d$USP9X[is.finite(d$USP9X)]
    limits <- if (length(values)) range(values) else c(0, 1)
    if (diff(limits) == 0) limits[[2]] <- limits[[1]] + 1
    shiny::updateSliderInput(session, "explorer_range", value = c(floor(limits[[1]] * 100) / 100, ceiling(limits[[2]] * 100) / 100))
  })

  filtered_cells <- shiny::reactive({
    d <- dataset_cells()
    patient <- sl_value(input$explorer_patient, "__all__")
    type <- sl_value(input$explorer_cell_type, "__all__")
    if (!identical(patient, "__all__") && any(!is.na(d$patient_id))) d <- d[!is.na(d$patient_id) & d$patient_id %in% patient, , drop = FALSE]
    if (!identical(type, "__all__")) d <- d[d$cell_type %in% type, , drop = FALSE]
    bounds <- input$explorer_range
    if (!is.null(bounds) && length(bounds) == 2) d <- d[is.na(d$USP9X) | (d$USP9X >= bounds[[1]] - 1e-8 & d$USP9X <= bounds[[2]] + 1e-8), , drop = FALSE]
    d
  })
  output$selection_summary <- shiny::renderUI({
    d <- filtered_cells()
    shiny::div(shiny::div(class = "selection-count", sl_n(nrow(d))),
      shiny::div(class = "selection-caption", "hücre seçildi · ", sl_n(sl_unique_n(d$cell_type)), " referans etiket"))
  })
  output$explorer_note <- shiny::renderUI({
    selected <- input$explorer_dataset
    d <- dataset_cells()
    denominator <- NULL
    for (item in dataset_metadata) if (is.list(item) && identical(item$id, selected)) denominator <- item$usp9x_denominator
    denominator_note <- if (!is.null(denominator)) shiny::div(shiny::strong("USP9X normalizasyon paydası: "), denominator) else NULL
    if (identical(selected, uploaded_choice)) return(shiny::div(class = "note-box warning-note", shiny::strong("Kullanıcı yüklemesi: "), "Bu tablo doğrulanmış proje paketi dışında tutulur. Yalnızca hücre keşfi ve dışa aktarım için kullanılır."))
    if (any(d$prediction_type %in% "frozen_external_transfer")) return(shiny::div(class = "note-box warning-note", "Dış kohort: marker temelli referans etiketleri ve dondurulmuş model tahminleri keşif amaçlıdır. Skorlar kohort içinde hesaplanmıştır.", denominator_note))
    if (!any(!is.na(d$patient_id))) return(shiny::div(class = "note-box", "Sağlıklı referans: kaynak anotasyonları gösterilir. Doğrulanmış hasta kimliği ve model tahmini bulunmadığı için hasta bazında karşılaştırma yapılmaz.", denominator_note))
    shiny::div(class = "note-box", "Geliştirme kohortu: USP9X log1p(CP10K) ölçeğinde; FibroScore1 kaynak paketteki özgün skordur. UMAP koordinatları kaynak Seurat nesnesinden alınmıştır.", denominator_note)
  })
  feature_plot <- shiny::reactive({
    d <- filtered_cells()
    feature <- sl_value(input$explorer_feature, "USP9X")
    group <- sl_value(input$explorer_group, "cell_type")
    shiny::validate(shiny::need(nrow(d), "Bu filtrelerde hücre bulunamadı."), shiny::need(feature %in% names(d), "Seçilen ölçüm bu veri setinde bulunmuyor."))
    if (!group %in% names(d) || all(is.na(d[[group]]))) group <- "cell_type"
    d$.value <- d[[feature]]
    d$.group <- as.character(d[[group]])
    d <- d[is.finite(d$.value) & !is.na(d$.group), , drop = FALSE]
    shiny::validate(shiny::need(nrow(d), "Seçilen ölçüm için sayısal kayıt bulunmuyor."))
    d$.group <- factor(d$.group, levels = sort(unique(d$.group)))
    ggplot2::ggplot(d, ggplot2::aes(x = .group, y = .value, fill = .group)) +
      ggplot2::geom_boxplot(width = .48, alpha = .65, outlier.shape = NA, linewidth = .35, colour = "#68606A") +
      ggplot2::geom_point(position = ggplot2::position_jitter(width = .15, seed = 23), size = if (nrow(d) > 3000) .45 else 1, alpha = if (nrow(d) > 3000) .18 else .35, colour = "#A03144") +
      ggplot2::scale_fill_manual(values = sl_palette(nlevels(d$.group))) +
      ggplot2::labs(x = NULL, y = score_label(feature)) + sl_theme() +
      ggplot2::theme(legend.position = "none", axis.text.x = ggplot2::element_text(angle = 25, hjust = 1, size = 9))
  })
  output$feature_distribution <- shiny::renderPlot(feature_plot(), res = 105)
  output$cell_composition <- shiny::renderPlot({
    d <- filtered_cells()
    shiny::validate(shiny::need(nrow(d), "Bu filtrelerde hücre bulunamadı."))
    counts <- as.data.frame(table(d$cell_type), stringsAsFactors = FALSE)
    names(counts) <- c("label", "n")
    counts$label <- factor(counts$label, levels = counts$label[order(counts$n)])
    ggplot2::ggplot(counts, ggplot2::aes(label, n, fill = label)) + ggplot2::geom_col(width = .62) +
      ggplot2::coord_flip() + ggplot2::scale_fill_manual(values = sl_palette(nrow(counts))) +
      ggplot2::labs(x = NULL, y = "Hücre sayısı") + sl_theme() + ggplot2::theme(legend.position = "none")
  }, res = 100)
  umap_available <- shiny::reactive({
    d <- filtered_cells()
    all(c("umap_1", "umap_2") %in% names(d)) && any(is.finite(d$umap_1) & is.finite(d$umap_2))
  })
  output$umap_content <- shiny::renderUI({
    if (umap_available()) return(shiny::tagList(shiny::plotOutput("umap_plot", height = "255px"), shiny::downloadButton("download_umap", "UMAP · PNG")))
    shiny::div(class = "empty-state", shiny::strong("UMAP koordinatı bulunmuyor"), "Bu veri kaynağında veya filtrede doğrulanmış koordinat yok. Yeni boyut indirgeme sonucu üretilmedi.")
  })
  umap_plot <- shiny::reactive({
    shiny::req(umap_available())
    d <- filtered_cells()
    d <- d[is.finite(d$umap_1) & is.finite(d$umap_2), , drop = FALSE]
    feature <- sl_value(input$explorer_feature, "USP9X")
    if (!feature %in% names(d)) feature <- "USP9X"
    d$.colour <- d[[feature]]
    ggplot2::ggplot(d, ggplot2::aes(umap_1, umap_2, colour = .colour)) +
      ggplot2::geom_point(size = 1.5, alpha = .8) +
      ggplot2::scale_colour_gradient(low = "#F4E5E8", high = "#BD1F36", na.value = "#eeeeee") +
      ggplot2::labs(x = "UMAP 1", y = "UMAP 2", colour = score_label(feature)) + sl_theme() +
      ggplot2::theme(legend.title = ggplot2::element_text(size = 8), legend.position = "right")
  })
  output$umap_plot <- shiny::renderPlot(umap_plot(), res = 105)
  output$cell_table <- DT::renderDT({
    d <- filtered_cells()
    populated <- vapply(d, function(x) any(!is.na(x) & as.character(x) != ""), logical(1))
    sl_table(d[, populated | names(d) %in% c("patient_id", "USP9X"), drop = FALSE], 8L)
  }, server = TRUE)

  output$overview_kpis <- shiny::renderUI({
    p <- sl_value(data$permutation_status$p_value_plus_one, NA_real_)
    shiny::div(class = "kpi-grid",
      sl_kpi("GELİŞTİRME KOHORTU", sl_n(nrow(main_cells)), "Tek hücre · GSE173278"),
      sl_kpi("BAĞIMSIZ HASTA", sl_n(sl_unique_n(main_cells$patient_id)), "Hasta dışarıda bırakmalı doğrulama"),
      sl_kpi("HASTA ORTALAMASI · MAKRO F1", sl_format(main_patient_f1()), "Ana V5 · kalibrasyonsuz OOF", TRUE),
      sl_kpi("PERMÜTASYON P", sl_format(p, 6), paste0(sl_n(sl_value(data$permutation_status$completed, NA_real_)), " permütasyon · +1 düzeltmesi")))
  })
  output$overview_composition <- shiny::renderPlot({
    shiny::validate(shiny::need(nrow(main_cells), "Geliştirme kohortu bulunamadı."))
    compact <- sl_value(session$clientData$output_overview_composition_width, 1000) < 450
    ggplot2::ggplot(main_cells, ggplot2::aes(patient_id, fill = cell_type)) +
      ggplot2::geom_bar(width = .68) + ggplot2::scale_fill_manual(values = sl_palette(sl_unique_n(main_cells$cell_type))) +
      ggplot2::guides(fill = ggplot2::guide_legend(ncol = if (compact) 1L else 3L, byrow = TRUE)) +
      ggplot2::labs(x = NULL, y = "Hücre sayısı") + sl_theme() +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = if (compact) 60 else 25, hjust = 1),
        legend.key.height = grid::unit(if (compact) .3 else .4, "cm"))
  }, res = 105)
  output$dataset_inventory <- DT::renderDT({
    inventory <- do.call(rbind, lapply(dataset_ids, function(id) {
      d <- all_cells[all_cells$dataset == id, , drop = FALSE]
      scores <- setdiff(numeric_scores(d), "USP9X")
      data.frame("Veri seti" = id, "Kapsam" = label_for_dataset(id), "Hücre" = nrow(d),
        "Hasta / donör" = if (sl_unique_n(d$patient_id)) as.character(sl_unique_n(d$patient_id)) else "Doğrulanmadı",
        "UMAP" = if (all(c("umap_1", "umap_2") %in% names(d)) && any(is.finite(d$umap_1) & is.finite(d$umap_2))) "Kaynak koordinatları mevcut" else "Yok",
        "Skor alanları" = if (length(scores)) paste(scores, collapse = ", ") else "Kaynak skor yok", check.names = FALSE)
    }))
    sl_table(inventory, search = FALSE, digits = 0L)
  }, server = FALSE)

  current_stage <- shiny::reactive(sl_value(input$model_stage, main_stage))
  current_metrics <- shiny::reactive(metric_rows(current_stage()))
  current_patients <- shiny::reactive(patient_rows(current_stage()))
  output$model_context <- shiny::renderUI({
    if (identical(current_stage(), secondary_stage)) return(shiny::div(class = "note-box warning-note", shiny::strong("İkincil analiz: "), "Kalibre edilmiş OOF tahminler ayrı değerlendirilir. Ana rapor ölçütü olarak kalibrasyonsuz V5 sonucu kullanılır."))
    shiny::div(class = "note-box", shiny::strong("Ana analiz: "), "Kalibrasyonsuz V5; hasta dışarıda bırakmalı OOF tahminler. Hasta ortalaması tüm hastalara eşit ağırlık verir.")
  })
  output$model_kpis <- shiny::renderUI({
    p <- current_patients()
    accuracy <- metric_value(current_stage(), "^accuracy$", "pooled|cell")
    if (is.na(accuracy)) accuracy <- metric_value(current_stage(), "pooled.*accuracy|accuracy.*pooled")
    pooled_f1 <- metric_value(current_stage(), "macro.*f1|f1.*macro", "pooled|cell")
    shiny::div(class = "kpi-grid",
      sl_kpi("HASTA ORTALAMASI · MAKRO F1", sl_format(main_patient_f1(current_stage())), "Hastalara eşit ağırlık", TRUE),
      sl_kpi("HAVUZLANMIŞ · MAKRO F1", sl_format(pooled_f1), "Tüm OOF hücreler birlikte"),
      sl_kpi("HAVUZLANMIŞ DOĞRULUK", sl_format(accuracy), "Tüm OOF hücreler birlikte"),
      sl_kpi("DEĞERLENDİRİLEN HASTA", sl_n(sl_unique_n(p$patient_id)), "Hasta bazlı çapraz doğrulama"))
  })
  output$confusion_plot <- shiny::renderPlot({
    d <- data$confusion[data$confusion$stage %in% current_stage(), , drop = FALSE]
    shiny::validate(shiny::need(nrow(d), "Bu analiz katmanı için karışıklık matrisi bulunmuyor."))
    labels <- sort(unique(c(d$true_label, d$predicted_label)))
    d$true_label <- factor(d$true_label, levels = rev(labels))
    d$predicted_label <- factor(d$predicted_label, levels = labels)
    ggplot2::ggplot(d, ggplot2::aes(predicted_label, true_label, fill = n)) +
      ggplot2::geom_tile(colour = "white", linewidth = 1.5) +
      ggplot2::geom_text(ggplot2::aes(label = n), colour = "#292A2F", size = 4.2, fontface = "bold") +
      ggplot2::scale_fill_gradient(low = "#FCF5F7", high = "#DBA1AC") +
      ggplot2::labs(x = "Model etiketi", y = "Referans etiketi") + sl_theme() +
      ggplot2::theme(legend.position = "none", panel.grid = ggplot2::element_blank(),
        axis.text.x = ggplot2::element_text(angle = 23, hjust = 1, size = 8), axis.text.y = ggplot2::element_text(size = 8))
  }, res = 105)
  output$patient_performance <- shiny::renderPlot({
    d <- current_patients()
    shiny::validate(shiny::need(nrow(d) && "macro_f1_present_true_classes" %in% names(d), "Hasta bazında makro F1 kaydı bulunmuyor."))
    d$patient_id <- factor(d$patient_id, levels = d$patient_id[order(d$macro_f1_present_true_classes)])
    ggplot2::ggplot(d, ggplot2::aes(patient_id, macro_f1_present_true_classes)) +
      ggplot2::geom_col(fill = "#BD1F36", width = .62) +
      ggplot2::geom_hline(yintercept = mean(d$macro_f1_present_true_classes, na.rm = TRUE), colour = "#49525C", linetype = "dashed", linewidth = .65) +
      ggplot2::coord_flip() + ggplot2::scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, .25)) +
      ggplot2::labs(x = NULL, y = "Makro F1 · kesikli çizgi hasta ortalaması") + sl_theme()
  }, res = 105)
  output$metrics_table <- DT::renderDT(sl_table(current_metrics(), digits = 6L), server = FALSE)
  output$patient_metrics_table <- DT::renderDT(sl_table(current_patients(), digits = 4L), server = FALSE)
  output$permutation_content <- shiny::renderUI({
    if (!length(data$permutation_status)) return(NULL)
    sl_card("Permütasyon denetimi", DT::DTOutput("permutation_table"),
      subtitle = "İstatistiksel denetim ana kalibrasyonsuz model içindir. İkincil kalibre edilmiş sonuca otomatik taşınmaz.")
  })
  output$permutation_table <- DT::renderDT({
    p <- sl_value(data$permutation_status, list())
    keys <- c("completed", "n_permutations", "observed_score", "exceedances_ge_observed", "p_value_plus_one")
    keys <- intersect(keys, names(p))
    pm <- data.frame(metric = keys, value = vapply(keys, function(nm) as.numeric(p[[nm]]), numeric(1)), stringsAsFactors = FALSE)
    sl_table(pm, search = FALSE, digits = 6L)
  }, server = FALSE)

  output$external_kpis <- shiny::renderUI({
    f1 <- metric_value(external_stage, "macro.*f1|f1.*macro")
    shiny::div(class = "kpi-grid",
      sl_kpi("DIŞ KOHORT", sl_n(nrow(external_cells)), "Stromal hücre · GSE141946"),
      sl_kpi("DIŞ DONÖR", sl_n(sl_unique_n(external_cells$patient_id)), "Kaynak donör eşlemesi"),
      sl_kpi("MARKER UYUMU · MAKRO F1", sl_format(f1), "Keşifsel referans karşılaştırması"),
      sl_kpi("SAĞLIKLI REFERANS", sl_n(nrow(healthy_cells)), "QC sonrası hücre · GSE97930"))
  })
  output$external_predictions <- shiny::renderPlot({
    d <- external_cells
    shiny::validate(shiny::need(nrow(d) && "predicted_label" %in% names(d), "Dış kohort tahminleri bulunmuyor."))
    ggplot2::ggplot(d, ggplot2::aes(patient_id, fill = predicted_label)) +
      ggplot2::geom_bar(width = .55) + ggplot2::scale_fill_manual(values = sl_palette(sl_unique_n(d$predicted_label))) +
      ggplot2::labs(x = "Kaynak donör", y = "Hücre sayısı") + sl_theme()
  }, res = 105)
  output$external_metrics_table <- DT::renderDT(sl_table(metric_rows(external_stage), digits = 5L), server = FALSE)
  output$healthy_context <- shiny::renderUI({
    shiny::div(class = "note-box", "Sağlıklı veri seti farklı bir deneysel bağlamdır. Ekspresyon dağılımları tümör verisiyle doğrudan bir tedavi seçiciliği karşılaştırması oluşturmaz. Doğrulanmış donör kimliği olmadığı için hasta sayısı gösterilmez.")
  })
  healthy_summary <- shiny::reactive({
    if (!nrow(healthy_cells)) return(data.frame())
    groups <- split(healthy_cells, interaction(healthy_cells$dataset, healthy_cells$cell_type, drop = TRUE))
    do.call(rbind, lapply(groups, function(d) data.frame(dataset = d$dataset[[1]], cell_type = d$cell_type[[1]], n_cells = nrow(d),
      USP9X_mean = mean(d$USP9X, na.rm = TRUE), USP9X_median = stats::median(d$USP9X, na.rm = TRUE),
      USP9X_positive_fraction = mean(d$USP9X > 0, na.rm = TRUE), stringsAsFactors = FALSE)))
  })
  output$healthy_expression <- shiny::renderPlot({
    d <- healthy_cells[is.finite(healthy_cells$USP9X), , drop = FALSE]
    shiny::validate(shiny::need(nrow(d), "Sağlıklı referans ekspresyonu bulunmuyor."))
    medians <- tapply(d$USP9X, d$cell_type, stats::median)
    d$cell_type <- factor(d$cell_type, levels = names(sort(medians)))
    ggplot2::ggplot(d, ggplot2::aes(cell_type, USP9X, fill = cell_type)) +
      ggplot2::geom_boxplot(width = .62, outlier.alpha = .1, outlier.size = .5, linewidth = .3) +
      ggplot2::coord_flip() + ggplot2::scale_fill_manual(values = sl_palette(nlevels(d$cell_type))) +
      ggplot2::labs(x = "Kaynak hücre sınıfı", y = "USP9X · log1p(CP10K)") + sl_theme() + ggplot2::theme(legend.position = "none")
  }, res = 105)
  output$healthy_summary_table <- DT::renderDT(sl_table(healthy_summary()), server = FALSE)
  output$sources_table <- DT::renderDT({
    d <- sl_value(data$sources, data.frame())
    if (!ncol(d)) d <- data.frame("Kaynak" = "Ayrıntılı kaynak ve dosya karmaları indirilebilir JSON kaydındadır.", check.names = FALSE)
    sl_table(d, digits = 0L)
  }, server = FALSE)
  output$provenance_info <- shiny::renderUI({
    p <- sl_value(data$provenance, list())
    fields <- p[vapply(p, function(x) is.atomic(x) && length(x) == 1, logical(1))]
    if (!length(fields)) fields <- list("Veri seti" = paste(dataset_ids, collapse = ", "), "Kayıt" = "Tam kaynak bilgisi indirilebilir JSON dosyasında.")
    shiny::tags$dl(class = "provenance-grid", unlist(lapply(names(fields), function(nm) list(shiny::tags$dt(nm), shiny::tags$dd(as.character(fields[[nm]])))), recursive = FALSE))
  })

  shiny::observeEvent(input$upload_cells, {
    file <- input$upload_cells
    tryCatch({
      if (file$size > 50 * 1024^2) stop("CSV dosyası en fazla 50 MB olabilir.")
      d <- read_uploaded_cells(file$datapath)
      uploaded(d)
      upload_error(FALSE)
      upload_message(paste(sl_n(nrow(d)), "hücre yüklendi. Hücre keşfi sekmesinde kullanıcı yüklemesini seçebilirsiniz."))
      shiny::showNotification("CSV doğrulandı; hücre keşfine eklendi.", type = "message")
    }, error = function(e) {
      uploaded(NULL)
      upload_error(TRUE)
      upload_message(conditionMessage(e))
      shiny::showNotification("CSV yüklenemedi; hata açıklamasını kontrol edin.", type = "error")
    })
  })
  shiny::observeEvent(input$clear_upload, {
    uploaded(NULL)
    upload_error(FALSE)
    upload_message("Yüklenen veri kaldırıldı.")
    shiny::updateSelectInput(session, "explorer_dataset", choices = dataset_choices, selected = dataset_ids[[1]])
  })
  output$upload_status <- shiny::renderUI({
    if (is.null(upload_message())) return(shiny::p(class = "fine-print", "Henüz kullanıcı dosyası yüklenmedi."))
    shiny::div(class = if (upload_error()) "upload-error" else "upload-success", upload_message())
  })
  output$download_cells <- shiny::downloadHandler(
    filename = function() paste0("StopLaris_secili_hucreler_", Sys.Date(), ".csv"),
    content = function(file) safe_export_csv(filtered_cells(), file), contentType = "text/csv;charset=utf-8")
  output$download_feature_plot <- shiny::downloadHandler(
    filename = function() paste0("StopLaris_olcum_dagilimi_", Sys.Date(), ".png"),
    content = function(file) ggplot2::ggsave(file, feature_plot(), device = "png", width = 10, height = 6, dpi = 200, bg = "white"), contentType = "image/png")
  output$download_umap <- shiny::downloadHandler(
    filename = function() paste0("StopLaris_UMAP_", Sys.Date(), ".png"),
    content = function(file) ggplot2::ggsave(file, umap_plot(), device = "png", width = 8, height = 6, dpi = 200, bg = "white"), contentType = "image/png")
  output$download_metrics <- shiny::downloadHandler(filename = function() paste0("StopLaris_", current_stage(), "_olcutler.csv"),
    content = function(file) safe_export_csv(current_metrics(), file), contentType = "text/csv;charset=utf-8")
  output$download_patient_metrics <- shiny::downloadHandler(filename = function() paste0("StopLaris_", current_stage(), "_hasta_sonuclari.csv"),
    content = function(file) safe_export_csv(current_patients(), file), contentType = "text/csv;charset=utf-8")
  output$download_provenance <- shiny::downloadHandler(filename = function() "StopLaris_kaynak_kaydi.json",
    content = function(file) jsonlite::write_json(list(metadata = metadata, provenance = data$provenance), file, auto_unbox = TRUE, pretty = TRUE, null = "null"), contentType = "application/json")
  output$download_schema <- shiny::downloadHandler(filename = function() "StopLaris_bos_hucre_sablonu.csv",
    content = function(file) safe_export_csv(data.frame(dataset = character(), cell_id = character(), patient_id = character(), cell_type = character(),
      USP9X = numeric(), sample_id = character(), umap_1 = numeric(), umap_2 = numeric()), file), contentType = "text/csv;charset=utf-8")
}
