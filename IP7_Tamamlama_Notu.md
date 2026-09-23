# İP-7 — R Shiny arayüz prototipi

**Durum:** Araştırma prototipi kapsamında tamamlandı.  
**Tamamlanma tarihi:** 21 Eylül 2026.  
**Zaman planındaki karşılığı:** 5–6. ay, R Shiny arayüz prototipinin geliştirilmesi ve analiz çıktılarının entegrasyonu.

## Gerçekleşen kapsam

R Shiny uygulaması, güncel V5 analiz paketindeki gerçek hücre ve model çıktılarıyla bütünleştirildi. Kullanıcı veri seti, hasta/donör ve referans hücre etiketine göre filtreleme yapabilir; USP9X ekspresyonunu, mevcut özgün KİF/stromal skorları ve kaynakta bulunan UMAP koordinatlarını inceleyebilir. Model performansı, hasta bazında sonuçlar, karışıklık matrisi ve tamamlanmış permütasyon denetimi ayrı ekranda sunulur. Sağlıklı referans ve dış veri aktarımı kendi kapsamlarıyla gösterilir. CSV/PNG indirme, kaynak kayıtlarına erişim ve doğrulanmış CSV yükleme işlevleri eklendi.

| Beklenen çıktı | Teslim edilen kanıt |
|---|---|
| R Shiny arayüzü | `app.R`, `R/app_ui.R`, `R/app_server.R`, `www/style.css` |
| Gerçek veri entegrasyonu | Üç veri setinden 12.499 hücre; `data/` |
| USP9X ve KİF/stromal ölçümleri | Hasta, hücre etiketi ve ekspresyon aralığı filtreleri; özgün skor alanları |
| Model çıktılarının gösterimi | Ana OOF, ikincil kalibrasyon, hasta F1, karışıklık matrisi, 1.000 permütasyon sonucu |
| İndirilebilir sonuçlar | Filtrelenmiş hücre CSV'si, model tabloları, PNG grafikler, kaynak JSON'u |
| Çalıştırma ve kullanım | RStudio projesi, Windows/Linux/macOS başlatıcıları, `README_TR.md` |
| Yazılım doğrulaması | `validation/r_tests.json`, `validation/browser-qa-report.json`, `validation/http-qa-report.json` |
| Veri bütünlüğü | `validation/source_data_checks.json`, `data/provenance.json` |
| Arayüz ekranları | `validation/desktop-overview.png`, `desktop-explorer.png`, `desktop-models.png`, mobil ekranlar |

## Rapora aktarılabilecek ifade

İP-7 kapsamında R Shiny tabanlı araştırma arayüzü geliştirilmiş ve mevcut biyoinformatik analizler ile makine öğrenmesi çıktıları arayüze entegre edilmiştir. Prototip, veri seti ve hücre alt grubu seçimi, USP9X ekspresyonu ve mevcut stromal skorların görüntülenmesi, özgün UMAP koordinatlarının incelenmesi, model performansının değerlendirilmesi ve çıktıların indirilmesini sağlamaktadır. Uygulama gerçek proje verileriyle çalıştırılmış; veri eşleşmeleri, filtreler, dosya indirmeleri ve masaüstü/mobil görünüm test edilmiştir.

Bu tamamlama kaydı İP-7'nin yazılım kapsamına ilişkindir. Uygulama araştırma sonuçlarını görüntüler; yeni klinik tanı, prognoz veya tedavi önerisi üretmez. Önceki model doğrulamasıyla uygulama işlev testleri farklı doğrulama faaliyetleridir. İnternet üzerinde kalıcı yayın bu teslimin içinde değildir; uygulama R kurulu bilgisayarda çalıştırılabilir.


## 22 Eylül 2026 — logo ve hasta değerlendirmesi güncellemesi

Orijinal StopLaris logosu, kırmızı-beyaz marka tasarımı ve uyumlu grafik renkleri eklendi. Masaüstü ve mobil düzen korunur. Yeni **Hasta değerlendirmesi** sekmesi, 10 GSE173278 hastası için 0–10 göreli USP9X ifade indeksi, veri desteği, referans karşılaştırması ve CSV raporu sunar. Bu indeks bu sürümde eklenen betimsel bir araştırma özetidir; önceki model validasyonu indeksin klinik doğrulaması değildir. Klinik risk hesaplanamadığı arayüzde açıkça gösterilir. Ayrıntı: `Hasta_Degerlendirmesi_TR.md`.

Kaynak verilerin 18 dosyası değişmeden korunmuştur. Güncel yazılım testleri ve ekran görüntüleri `validation/` altında; güncel doğrulama özeti `DELIVERY_STATUS.json` içindedir. Yukarıdaki 21 Eylül kayıtları ilk sürümün tarihsel teslim kaydıdır.
