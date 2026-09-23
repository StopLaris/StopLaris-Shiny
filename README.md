# StopLaris

**R Shiny ile tek hücre araştırma platformu · v1.2.0 · 23 Eylül 2026**

Kaynak deposu: [StopLaris/StopLaris-Shiny](https://github.com/StopLaris/StopLaris-Shiny). Bu belge **v1.2.0** kaynak içeriğini tanımlar; sürüm referansı `refs/tags/v1.2.0` olarak belirlenmiştir. Deponun erişim ayarları, etiket/release yayını ve CI sonuçlarının güncel kanıtı ayrı yayımlama raporunda tutulur.

StopLaris, proje kapsamında hazırlanmış tek hücre verilerini, USP9X ekspresyonunu ve mevcut makine öğrenmesi çıktılarını etkileşimli olarak incelemek için geliştirilmiştir. Hazır analiz verileri depoda bulunur; uygulamayı açmak için model eğitimi gerekmez.

**Hasta değerlendirmesindeki 0–10 değer, sabit araştırma kohortunda göreli USP9X ifade indeksidir. Klinik risk veya hastalık olasılığı değildir.**

<img src="www/stoplaris-logo.png" width="180" alt="StopLaris logosu">

*Aşağıda bağlantıları verilen ekran görüntüleri, önceki v1.1.0 sürümünün 22 Eylül 2026 doğrulama kaydına aittir. v1.2.0 sürümünde başlık sadeleştirilmiş, tekrar eden giriş logosu kaldırılmıştır.*

## Kurulum ve çalıştırma

[R](https://www.r-project.org/) kurulu olmalıdır. RStudio isteğe bağlıdır. Kayıtlı yerel test ortamı R 4.3.3 kullanır; GitHub Actions yapılandırması R 4.4.3 hedefler.

1. Depoyu indirin ve arşivin tamamını çıkarın.
2. Terminali `app.R` dosyasının bulunduğu klasörde açın.
3. İlk kurulum ve başlatma komutlarını çalıştırın:

```sh
Rscript install.R
Rscript run_app.R
```

Tarayıcıda `http://127.0.0.1:3838` açılır. Durdurmak için terminalde **Ctrl+C** kullanın. İlk bağımlılık kurulumunda internet gerekir; paketler kurulduktan sonra hazır proje verileriyle çevrimdışı çalışır.

RStudio kullanıyorsanız `StopLaris_Shiny.Rproj` dosyasını açın; Console alanında `source("install.R")` çalıştırın ve `app.R` içindeki **Run App** düğmesini kullanın. Alternatif başlatıcılar: Windows için `Baslat.bat`, macOS/Linux için `bash baslat.sh`.

| Ayar | Varsayılan | İşlev |
|---|---|---|
| `STOPLARIS_PORT` | `3838` | Kullanılacak port; 1024–65535 aralığında |
| `STOPLARIS_HOST` | `127.0.0.1` | R sunucusunun dinleyeceği adres |
| `STOPLARIS_OPEN_BROWSER` | `true` | Otomatik tarayıcı açılışı |

Telefon görünümü için de çalışan bir R sunucusu gerekir. Bu depo yerel uygulama kaynaklarını içerir; çevrimiçi uygulama adresi tanımlanmamıştır.

## Neler yapılabilir?

| Sekme | İçerik |
|---|---|
| Genel bakış | Kohort özeti, hasta dağılımı ve veri envanteri |
| Hücre keşfi | Veri seti, hasta, hücre etiketi ve ekspresyon filtreleri; kaynak UMAP ve skorlar |
| Hasta değerlendirmesi | Sabit referanstaki 10 hastanın USP9X profili, hücre/örnek desteği ve yöntem bilgili CSV |
| Model sonuçları | Ana V5 OOF, ikincil kalibrasyon, hasta bazında ölçütler ve permütasyon denetimi |
| Dış aktarım ve referans | Dış kohort sonuçları ve sağlıklı referansta betimsel ekspresyon |
| Yöntem ve kaynak | Veri kökeni, ölçüm tanımları ve doğrulama kayıtları |
| Veri yükleme | Uyumlu CSV'nin oturum içinde keşfi |

Hücre ve model tabloları CSV, grafikler PNG olarak indirilebilir. Yüklenen dosyalar yeni hasta skoru üretmez; sabit hasta referansını ve kayıtlı model sonuçlarını değiştirmez.

[Hücre keşfi ekranı](validation/desktop-explorer.png) · [Hasta değerlendirmesi](validation/desktop-patient.png) · [Model sonuçları](validation/desktop-models.png) · [Mobil görünüm](validation/mobile-patient.png)

## Veri ve bilimsel kapsam

| Veri seti | Paket içindeki hücre | Rol |
|---|---:|---|
| GSE173278 | 842 | 10 hastadan oluşan ana geliştirme kohortu |
| GSE141946 | 1.404 | 3 donör ve 4 kaynak örnek üzerinden dış aktarım |
| GSE97930 | 10.253 | QC sonrası sağlıklı frontal korteks referansı |

Veri kökeni ve dönüşümler [data/provenance.json](data/provenance.json), kapsam ve ölçüm tanımları [data/metadata.json](data/metadata.json) içinde kayıtlıdır. Özgün UMAP koordinatları yalnızca mevcut oldukları kohortta gösterilir.

Hasta indeksi, GSE173278 içindeki hasta başına ortalama USP9X değerinin sırasını kullanır:

```text
İndeks = 10 × (ortalama sıra − 1) / (referans hasta sayısı − 1)
```

Eşit değerlere ortalama sıra verilir. Referans, seçilen hastayı da içerir. **10/10, yalnızca bu referanstaki en yüksek ortalamayı gösterir; %100 risk anlamına gelmez.** Hasta başına hücre sayısı ve örnek bileşimi yorumu sınırlar. Ayrıntılar: [Hasta_Degerlendirmesi_TR.md](Hasta_Degerlendirmesi_TR.md).

Model hedefleri marker kökenli hücre etiketleridir. Hasta bazında ve havuzlanmış hücre ölçütleri farklıdır; dış aktarım uyumu klinik doğrulama olarak yorumlanmaz. Paket, klinik sonlanım temelli nüks/sağkalım tahmini, tedavi önerisi veya USP9X için nedensel mekanizma kanıtı üretmez. [Bilimsel notlar](data/scientific_notes.md) bu sınırları ayrıntılandırır.

## Testler ve kayıtlı doğrulama

```sh
Rscript -e "install.packages('testthat', repos='https://cloud.r-project.org')"
Rscript tests/run_tests.R
```

22 Eylül 2026 tarihli paket kayıtları: **13 R testi / 142 başarılı doğrulama**, **74 tarayıcı kontrolü**, **23 HTTP/varlık kontrolü** ve **8 ekran görüntüsü**. Bunlar tarihsel yerel çalıştırma sonuçlarıdır. 23 Eylül 2026 tarihinde logo düzenlemesinin ardından R testleri yeniden çalıştırıldı: 13 test / 142 doğrulama geçti; 11 R dosyası ayrıştırıldı ve arayüz HTML çıktısında tek logo bulundu. 23 Eylül tarihli bu yerel kayıt yeni tarayıcı/mobil görsel kontrolü veya GitHub Actions çalışması içermez.

- [23 Eylül R kontrolü](validation/publication-r-checks-2026-09-23.json)
- [22 Eylül R test raporu](validation/r_tests.json)
- [Tarayıcı raporu](validation/browser-qa-report.json)
- [HTTP raporu](validation/http-qa-report.json)
- [Tarayıcı testlerini çalıştırma](validation/BROWSER_QA_README.md)

[GitHub Actions iş akışı](.github/workflows/r-tests.yml), push ve pull request olaylarında R testlerini çalıştırmak için hazırlanmıştır. Ubuntu 24.04 ve R 4.4.3 kullanır; paket sürümleri kilitlenmediğinden tarihsel ortamın birebir kopyası değildir. Tarayıcı testleri bu CI iş akışına dahil değildir.

## Depo yapısı

| Yol | Amaç |
|---|---|
| `app.R`, `run_app.R`, `install.R` | Uygulama girişi, başlatma ve bağımlılıklar |
| `R/` | Veri yükleme, arayüz, sunucu ve hasta profili modülü |
| `data/` | Hazırlanmış araştırma verileri ve kaynak kayıtları |
| `www/` | Logo ve stil dosyaları |
| `tests/` | Veri, sunucu ve hasta profili testleri |
| `validation/` | Tarihli test kayıtları, ekranlar ve tarayıcı araçları |
| `scripts/` | Kaynak paketten veri hazırlama ve açılış kontrolü |
| `docs/GITHUB_RELEASE_NOTES.md` | v1.2.0 kaynak sürüm notları |
| `docs/RAPOR_YAZILIM_ERISIMI_TR.md` | Final raporunda kullanılacak yazılım tanımı ve kaynak referansı |

Normal kullanımda Python gerekmez. Kaynak veriyi yeniden hazırlamak için `python scripts/prepare_data.py --help` komutuna ve kaynak arşive ihtiyaç vardır.

## Atıf ve lisans durumu

Yazılım atfı: **StopLaris Proje Ekibi. (2026). StopLaris: R Shiny tek hücre araştırma platformu (Sürüm 1.2.0).** [Kaynak deposu](https://github.com/StopLaris/StopLaris-Shiny); kaynak referansı: `refs/tags/v1.2.0`. Makine tarafından okunabilir kayıt [CITATION.cff](CITATION.cff) dosyasındadır. Kullanılan veri kaynakları ayrıca belirtilmelidir.

Kaynak ve hak notları: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Bu hazırlıkta yazılıma açık kaynak lisansı atanmadı. Lisans kararı proje ekibine aittir; üçüncü taraf veri ve yazılım kaynaklarının kendi koşulları korunur.

## English summary

StopLaris is a local R Shiny research application for exploring packaged single-cell data, USP9X expression and existing model outputs. Its 0–10 patient index is a descriptive rank within a fixed research cohort, **not a clinical risk probability**. Run `Rscript install.R`, then `Rscript run_app.R`. See the dated validation records for historical software checks.
