# Final raporu — yazılım ve kod erişimi

Bu belge, StopLaris **v1.2.0** kaynak sürümünün final raporunda kullanılabilecek teknik tanımını içerir. Kaynak deposu [StopLaris/StopLaris-Shiny](https://github.com/StopLaris/StopLaris-Shiny), sürüm referansı `refs/tags/v1.2.0` olarak belirlenmiştir. Depo erişimi, etiket/release yayını ve CI sonuçlarının güncel kanıtları kaynak paketten ayrı yayımlama raporunda belgelenir.

## Rapora aktarılabilecek teknik metin

StopLaris projesinin İP-7 çalışmaları kapsamında, analiz sonuçlarının etkileşimli incelenebilmesi için R Shiny tabanlı bir araştırma arayüzü geliştirilmiştir. Arayüz; hücre ve hasta bazında filtreleme, USP9X ekspresyonunun görselleştirilmesi, kaynak UMAP koordinatlarının incelenmesi, model performans sonuçlarının karşılaştırılması ve seçili sonuçların dışa aktarılması işlevlerini bir araya getirmektedir. Geliştirme kohortu, dış veri aktarımı ve sağlıklı referans verileri özgün kapsamlarıyla ayrı olarak sunulmaktadır.

Hasta değerlendirmesi bölümünde, GSE173278 kohortundaki 10 hastanın ortalama USP9X ifade düzeylerinin sabit referans içindeki sıralamasından hesaplanan 0–10 göreli ifade indeksi gösterilmektedir. Bu betimsel indeks klinik risk olasılığı, sağkalım/nüks tahmini veya tedavi önerisi değildir. Kaynak hücre etiketlerinin sınıflandırılmasına ait model performansı, bu indeksin klinik doğrulaması olarak değerlendirilmemektedir.

Yeniden çalıştırılabilirliği desteklemek üzere kaynak kod, kurulum ve çalıştırma yönergeleri, bağımlılık bilgileri, veri kökeni kayıtları ve yazılım testleri aynı teslim paketinde düzenlenmiştir. Paket, yeni bir CSV yüklemesi için model eğitimi veya yeni hasta risk tahmini yapmamaktadır. GitHub üzerinde kaynak kod paylaşımı ile uygulamanın çevrimiçi çalıştırılması ayrı işlemlerdir; bu teslim bir canlı uygulama adresi içermez.

## Kaynak sürümünün tanımı

| Alan | Değer |
|---|---|
| Yazılım | StopLaris R Shiny araştırma prototipi |
| Kaynak sürümü | 1.2.0 |
| GitHub deposu | [StopLaris/StopLaris-Shiny](https://github.com/StopLaris/StopLaris-Shiny) |
| Kaynak referansı (`source_ref`) | `refs/tags/v1.2.0` |
| Yazılım atfı | StopLaris Proje Ekibi (2026), StopLaris, Sürüm 1.2.0 |
| DOI | Atanmadı |

Kaynak referansı bu paketin sürüm tanımıdır. Deponun herkese açık erişimi, etiket/release oluşturulması veya CI başarısı bu tablodan çıkarılmamalıdır. Final raporuna doğrulanan release bağlantısı, yayın tarihi ve erişim bilgisi eklenirken ayrı yayımlama kaydı esas alınmalıdır. Kaynak dosyalarına kendi commit kimliği yazılmaz.

## Yazılım doğrulamasının kapsamı

23 Eylül 2026 tarihli [R doğrulama kaydı](../validation/publication-r-checks-2026-09-23.json), 13 testte 142 başarılı doğrulamayı, 11 R dosyasının ayrıştırılmasını ve arayüz HTML çıktısında tek logo bulunduğunu belgeler. Yeni tarayıcı veya mobil görsel kontrolü içermez.

Paket içindeki 74 tarayıcı kontrolü, 23 HTTP/varlık kontrolü ve 8 masaüstü/mobil ekran görüntüsü önceki v1.1.0 sürümünün 22 Eylül 2026 kaydına aittir. Bu yazılım kontrolleri klinik doğrulama veya GitHub Actions başarı kanıtı değildir.
