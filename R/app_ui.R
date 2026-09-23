sl_card <- function(title, ..., subtitle = NULL, class = NULL) {
  shiny::tags$section(class = paste("sl-card", class),
    shiny::div(class = "card-heading", shiny::h3(title),
      if (!is.null(subtitle)) shiny::p(class = "muted", subtitle)), ...)
}

sl_intro <- function(kicker, title, text) {
  shiny::div(class = "section-intro", shiny::div(class = "eyebrow", kicker),
    shiny::h2(title), shiny::p(text))
}

app_ui <- function() {
  shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      shiny::tags$title("StopLaris | Tek hücre araştırma platformu"),
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "style.css")
    ),
    shiny::div(class = "app-shell",
      shiny::tags$header(class = "app-header",
        shiny::div(class = "brand-group",
          shiny::div(class = "brand-logo-panel", shiny::tags$img(src = "stoplaris-logo.png", alt = "StopLaris logosu", class = "brand-logo")),
          shiny::div(class = "brand-description", shiny::span(class = "brand-category", "ONKOLOJİ ARAŞTIRMALARI"),
            shiny::h1("Tek hücre araştırma platformu"))),
        shiny::div(class = "header-meta", shiny::span(class = "status-dot"), "Araştırma çalışma alanı")
      ),
      shiny::div(class = "research-strip", "Araştırma amaçlıdır. Hücre etiketleri ve model çıktıları klinik tanı, prognoz veya tedavi önerisi değildir."),
      shiny::tabsetPanel(id = "main_tab", type = "tabs",
        shiny::tabPanel("Genel bakış", value = "overview",
          shiny::div(class = "hero-panel",
            shiny::div(class = "hero-copy",
              shiny::div(class = "eyebrow", "FİBROBLAST ODAKLI ANALİZ"),
              shiny::h2("Hücresel veriden", shiny::tags$br(), "araştırma bulgularına."),
              shiny::p("USP9X ekspresyonunu, mevcut stromal hücre skorlarını ve hasta dışarıda bırakmalı model değerlendirmelerini aynı çalışma alanında inceleyin."),
              shiny::div(class = "hero-pills", shiny::span("Gerçek analiz verileri"), shiny::span("Hasta bazında değerlendirme"), shiny::span("Kaynak takibi"))
            )
          ),
          shiny::uiOutput("overview_kpis"),
          shiny::div(class = "two-col",
            sl_card("Geliştirme kohortu", shiny::plotOutput("overview_composition", height = "330px"),
              subtitle = "Hasta ve referans hücre etiketi dağılımı; ana V5 kohortu."),
            sl_card("Bulguların okuma rehberi",
              shiny::div(class = "finding", shiny::span(class = "finding-number", "01"), shiny::div(shiny::h4("Ana sonuç: kalibrasyonsuz OOF"), shiny::p("Her hastanın hücreleri, o hasta eğitime dahil edilmeden tahmin edildi. Hasta başına makro F1 değerlerinin ortalaması ana ölçüttür."))),
              shiny::div(class = "finding", shiny::span(class = "finding-number", "02"), shiny::div(shiny::h4("Dış aktarım ayrı değerlendirilir"), shiny::p("Bağımsız veri setindeki marker referans uyumu, iç doğrulama başarısı veya klinik geçerlilikle eş tutulmaz."))),
              shiny::div(class = "finding", shiny::span(class = "finding-number", "03"), shiny::div(shiny::h4("Sağlıklı referans keşif amaçlıdır"), shiny::p("Kaynak ve hücre sınıfı bilgisi korunur. Doğrulanmış donör eşlemesi bulunmadığında hasta bazında karşılaştırma yapılmaz.")))
            )
          ),
          sl_card("Veri envanteri", DT::DTOutput("dataset_inventory"), subtitle = "Her kaynağın kapsamı ve kullanılabilen alanları.")
        ),
        shiny::tabPanel("Hücre keşfi", value = "explorer",
          sl_intro("VERİ KEŞFİ", "Hücreleri ve ekspresyonu inceleyin", "Önce veri kaynağını seçin. Filtreler bu sekmedeki grafiklere ve CSV dışa aktarımına uygulanır; doğrulama sonuçlarını değiştirmez."),
          shiny::div(class = "explorer-layout",
            shiny::tags$aside(class = "filter-panel",
              shiny::h3("Seçimi daraltın"),
              shiny::selectInput("explorer_dataset", "Veri seti", choices = NULL),
              shiny::uiOutput("patient_filter_ui"),
              shiny::selectInput("explorer_cell_type", "Referans hücre etiketi", choices = c("Tümü" = "__all__")),
              shiny::selectInput("explorer_feature", "Gösterilecek ölçüm", choices = c("USP9X · log1p(CP10K)" = "USP9X")),
              shiny::selectInput("explorer_group", "Grafik gruplaması", choices = c("Hücre etiketi" = "cell_type", "Hasta / donör" = "patient_id")),
              shiny::sliderInput("explorer_range", "USP9X aralığı · log1p(CP10K)", min = 0, max = 1, value = c(0, 1), step = 0.01),
              shiny::actionButton("reset_filters", "Filtreleri sıfırla", class = "btn-block btn-default"),
              shiny::hr(), shiny::uiOutput("selection_summary"),
              shiny::downloadButton("download_cells", "Seçili hücreler · CSV", class = "btn-block"),
              shiny::p(class = "fine-print", "Eksik değerler grafikte kullanılmaz. CSV, tablonun arama ve sıralamasından bağımsız olarak soldaki filtreleri izler.")
            ),
            shiny::div(class = "explorer-content",
              shiny::uiOutput("explorer_note"),
              sl_card("Ölçüm dağılımı", shiny::plotOutput("feature_distribution", height = "370px"),
                shiny::downloadButton("download_feature_plot", "Grafiği indir · PNG"),
                subtitle = "Noktalar tek hücreleri, kutular medyan ve çeyrekleri gösterir."),
              shiny::div(class = "two-col",
                sl_card("Hücre kompozisyonu", shiny::plotOutput("cell_composition", height = "290px")),
                sl_card("UMAP görünümü", shiny::uiOutput("umap_content"),
                  subtitle = "Yalnızca kaynak pakette koordinat bulunan hücreler.")
              ),
              sl_card("Hücre kayıtları", DT::DTOutput("cell_table"),
                subtitle = "Sağa kaydırarak skorları, kaynak bilgilerini ve mevcut tahminleri inceleyebilirsiniz.")
            )
          )
        ),
        patient_assessment_ui(),
        shiny::tabPanel("Model sonuçları", value = "models",
          sl_intro("DOĞRULAMA", "Model performansını bağlamıyla okuyun", "Ana V5 sonuçları hasta dışarıda bırakmalı doğrulamaya dayanır. Kalibre edilmiş sonuçlar ikincil inceleme olarak ayrı tutulur."),
          shiny::div(class = "control-row", shiny::selectInput("model_stage", "Analiz katmanı", choices = NULL, width = "100%")),
          shiny::uiOutput("model_context"), shiny::uiOutput("model_kpis"),
          shiny::div(class = "two-col",
            sl_card("Karışıklık matrisi", shiny::plotOutput("confusion_plot", height = "370px"),
              subtitle = "Havuzlanmış hücre sayıları. Satırlar referans, sütunlar model etiketidir."),
            sl_card("Hasta başına performans", shiny::plotOutput("patient_performance", height = "370px"),
              subtitle = "Her hastada bulunan gerçek sınıflar üzerinden hesaplanan makro F1.")
          ),
          shiny::div(class = "two-col",
            sl_card("Doğrulama ölçütleri", DT::DTOutput("metrics_table"), shiny::downloadButton("download_metrics", "Ölçütler · CSV")),
            sl_card("Hasta bazında sonuçlar", DT::DTOutput("patient_metrics_table"), shiny::downloadButton("download_patient_metrics", "Hasta sonuçları · CSV"))
          ),
          shiny::uiOutput("permutation_content"),
          shiny::div(class = "note-box", shiny::strong("Yorum sınırı: "), "Bu metrikler kaynak hücre etiketlerini yeniden üretme başarısını gösterir. USP9X için nedensellik, tedavi hedefi geçerliliği veya hastaya ait klinik sonuç kanıtı oluşturmaz.")
        ),
        shiny::tabPanel("Dış aktarım ve referans", value = "external",
          sl_intro("BAĞIMSIZ KONTROLLER", "Aktarılabilirliği ve referansları ayırın", "Dış kohorttaki dondurulmuş model tahminleri ile sağlıklı referans ekspresyonu farklı bilimsel soruları yanıtlar."),
          shiny::uiOutput("external_kpis"),
          shiny::div(class = "note-box warning-note", shiny::strong("Belirgin veri dağılımı farkı: "), "Dış kohortta düşük marker referans uyumu görülür. Bu sonuç dış doğrulama başarısı olarak sunulamaz; marker temelli etiketler bağımsız biyolojik altın standart değildir."),
          shiny::div(class = "two-col",
            sl_card("Dış kohort tahmin dağılımı", shiny::plotOutput("external_predictions", height = "340px"), subtitle = "Dondurulmuş araştırma modeli; donör bazında hücre sayıları."),
            sl_card("Dış aktarım ölçütleri", DT::DTOutput("external_metrics_table"),
              shiny::p(class = "fine-print", "domain_classifier_auc: veri kümelerini ayırt etme AUC değeridir; CAF alt tipi sınıflandırma başarısı değildir."),
              subtitle = "İç doğrulama tablosundan ayrı gösterilir.")
          ),
          sl_card("Sağlıklı referansta USP9X", shiny::uiOutput("healthy_context"), shiny::plotOutput("healthy_expression", height = "410px"),
            subtitle = "Kaynak anotasyonları korunur. Ekspresyon log1p(CP10K) ölçeğindedir."),
          sl_card("Sağlıklı referans hücre sınıfları", DT::DTOutput("healthy_summary_table"),
            subtitle = "Yalnızca betimsel özet; kohortlar arasında birleştirilmiş anlamlılık testi yapılmaz.")
        ),
        shiny::tabPanel("Yöntem ve kaynak", value = "methods",
          sl_intro("İZLENEBİLİRLİK", "Ölçümler, kapsam ve kaynaklar", "Bu prototip tamamlanmış analiz çıktılarının etkileşimli inceleme katmanıdır. Model yeniden eğitimi veya klinik tahmin servisi çalıştırmaz."),
          shiny::div(class = "two-col",
            sl_card("Ekspresyon ve skorlar",
              shiny::h4("USP9X"), shiny::p("USP9X = log1p(ham gen sayımı / kaynağa özgü kütüphane toplamı × 10.000). Payda geliştirme ve dış kohortta tam gen evreninden; sağlıklı referansta en az üç hücrede saptanan gen filtresinden gelir. Hücre keşfinde veri setine ait payda açıklanır. Dış model olasılıkları ayrı, kayıtlı aligned-input normalizasyonundan gelir."),
              shiny::h4("CAF / KİF skorları"), shiny::p("Arayüz yalnızca veri paketinde bulunan skorları gösterir. Geliştirme kohortundaki FibroScore1 ile dış kohorttaki inflammatory_iCAF_z, contractile_myCAF_z ve stromal_perivascular_z alanları özgün adlarıyla korunur. emCAF veya klinik risk skoru üretilmez."),
              shiny::h4("Hücre etiketleri"), shiny::p("iCAF_like_uncertain, myCAF_like ve pericyte_vCAF_like araştırma referans etiketleridir. '_like' ve 'uncertain' nitelemeleri biyolojik belirsizliği korur.")
            ),
            sl_card("Model ve değerlendirme",
              shiny::h4("V5 ana analiz"), shiny::p("Hasta dışarıda bırakmalı çapraz doğrulama; özellik seçimi ve parametre seçimi eğitim bölümünde yürütülür. Ana sonuç kalibrasyonsuz OOF tahminlerden elde edilir."),
              shiny::h4("Toplulaştırma"), shiny::p("Hasta başına makro F1 ortalaması ile tüm hücrelerin havuzlanmış makro F1 değeri farklı ölçütlerdir. Tablolardaki toplulaştırma alanı korunur; sonuçlar birbirinin yerine kullanılmaz."),
              shiny::h4("Dış aktarım ve sağlıklı referans"), shiny::p("Dış model tahminleri, marker referans etiketleriyle keşifsel olarak karşılaştırılır. Sağlıklı referansların doğrulanmış hasta/donör eşlemesi yoktur; hastaya dayalı çıkarım yapılmaz.")
            )
          ),
          sl_card("Kaynak envanteri", DT::DTOutput("sources_table"), subtitle = "Veri dosyalarının kökeni ve doğrulama kaydı."),
          sl_card("Paket bilgisi", shiny::uiOutput("provenance_info"), shiny::downloadButton("download_provenance", "Kaynak kaydı · JSON"))
        ),
        shiny::tabPanel("Veri yükleme", value = "upload",
          sl_intro("YEREL ÇALIŞMA", "Kendi hücre tablonuzu keşfedin", "Uyumlu bir CSV dosyasını geçici olarak bu oturumda açın. Yükleme, paketlenmiş doğrulama sonuçlarını değiştirmez ve yeni model tahmini üretmez."),
          shiny::div(class = "two-col",
            sl_card("CSV yükle",
              shiny::fileInput("upload_cells", "UTF-8 CSV · en fazla 50 MB", accept = c(".csv", "text/csv")),
              shiny::uiOutput("upload_status"),
              shiny::actionButton("clear_upload", "Yüklenen veriyi kaldır", class = "btn-default"),
              shiny::p(class = "fine-print", "Tablo tarayıcı oturumunuz için işlenir; uygulama kaynak dosyalarını değiştirmez.")),
            sl_card("Beklenen alanlar",
              shiny::p("Zorunlu sütunlar: ", shiny::tags$code("dataset, cell_id, cell_type, USP9X")),
              shiny::p("İsteğe bağlı sütunlar: ", shiny::tags$code("patient_id, sample_id, USP9X_raw_counts, umap_1, umap_2"), " ve sayısal araştırma skorları."),
              shiny::p("USP9X alanı sonlu, negatif olmayan log1p(CP10K) değerleri veya boş değerler içermelidir. Hücre kimlikleri her veri setinde tekil olmalıdır."),
              shiny::p("Yüklenen dosyadaki hazır tahmin alanları araştırma verisi olarak kalır. Uygulama bunları doğrulanmış model sonucu olarak kullanmaz."),
              shiny::downloadButton("download_schema", "Boş CSV şablonu"))
          )
        )
      ),
      shiny::tags$footer(class = "app-footer", shiny::span("StopLaris · Araştırma platformu"), shiny::span("Veri keşfi · Sonuç entegrasyonu · Kaynak takibi"))
    )
  )
}
