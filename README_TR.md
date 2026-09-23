# StopLaris — R Shiny araştırma prototipi

İP-7 kapsamında, mevcut StopLaris analizlerini etkileşimli olarak incelemek için hazırlanmıştır. Gerçek proje verileri paket içindedir; uygulamayı açmak için analizleri veya model eğitimini yeniden çalıştırmak gerekmez.

## Açılış

1. ZIP dosyasının **tamamını** bir klasöre çıkarın.
2. R ve RStudio bulunan bilgisayarda `StopLaris_Shiny.Rproj` dosyasını açın.
3. RStudio Console alanında ilk kullanımda `source("install.R")` çalıştırın.
4. `app.R` dosyasını açıp **Run App** düğmesine basın. Alternatif: Console'da `source("run_app.R")`.

Komut satırında:

```sh
Rscript install.R
Rscript run_app.R
```

Uygulama varsayılan olarak `http://127.0.0.1:3838` adresinde açılır. Windows'ta Rscript PATH'e ekliyse `Baslat.bat`, macOS/Linux'ta `bash baslat.sh` aynı işlemi yapar. İlk kurulumda internet gerekir; bağımlılıklar kurulduktan sonra mevcut veri paketiyle çevrimdışı çalışır. Telefon ekranına uyumlu tasarım vardır; R sunucusunun bir bilgisayarda çalışması gerekir.

RStudio'da **Run App** kullanımı için proje klasörünü açık tutun. RStudio üzerinden açılan uygulamayı **Stop** ile, terminal üzerinden açılanı Ctrl+C ile durdurun. 3838 portu doluysa `STOPLARIS_PORT` ortam değişkenini farklı bir port yapın. `STOPLARIS_HOST` varsayılanı yalnızca yerel bilgisayardır. Bu teslim bir genel internet yayını içermez.

## Uygulamada bulunanlar

| Bölüm | İşlev |
|---|---|
| Genel bakış | Ana kohort, hasta dağılımı ve veri envanteri |
| Hücre keşfi | Veri seti, hasta/donör, hücre etiketi ve USP9X aralığı filtreleri; özgün UMAP; mevcut CAF/KİF skorları; aranabilir hücre tablosu |
| Hasta değerlendirmesi | Paket içindeki 10 hasta için 0–10 USP9X göreli ifade indeksi; hücre/örnek sayıları, kohort sıralaması ve indirilebilir hasta özeti |
| Model sonuçları | Ana V5 OOF ve ikincil kalibrasyon sonuçları; hasta bazında F1; karışıklık matrisi; permütasyon sonucu |
| Dış aktarım ve referans | Dondurulmuş modelin dış kohort sonuçları ve sağlıklı dokuda USP9X betimsel özeti |
| Yöntem ve kaynak | Veri kökeni, ölçüm tanımları ve kaynak doğrulama kayıtları |
| Veri yükleme | Uyumlu CSV'yi geçici olarak keşfetme; yüklenen veri resmi model metriklerini değiştirmez |

Filtrelenmiş hücre kayıtları ve model tabloları CSV, ekspresyon grafikleri PNG olarak indirilebilir. Hücre CSV indirmesi, sol paneldeki filtrelere uyar; veri tablosundaki metin araması ayrı bir görüntüleme işlemidir.

**22 Eylül 2026 güncellemesi:** Orijinal StopLaris logosu ve logoya uyumlu kırmızı-beyaz tasarım eklendi. Hasta değerlendirmesi bölümü mevcut hastaların moleküler profilini 0–10 ölçeğinde özetler. **Bu indeks klinik risk olasılığı değildir.** Pakette nüks/sağkalım sonlanımı ve doğrulanmış hasta risk modeli bulunmadığından klinik risk hesaplanmaz. Formül, kapsam ve yorumlama sınırları `Hasta_Degerlendirmesi_TR.md` dosyasındadır. Yüklenen yeni hastalara skor veya klinik tahmin atanmaz.

## Veri kapsamı

| Kaynak | Hücre sayısı | Hasta/donör kapsamı | Rol |
|---|---:|---|---|
| GSE173278 | 842 | 10 hasta | Ana V5 geliştirme kohortu ve hasta dışarıda bırakmalı OOF sonuçları |
| GSE141946 | 1.404 | 3 donör, 4 kaynak örnek | Dondurulmuş modelin dış veri aktarımı |
| GSE97930 | 10.253 | Doğrulanmış hasta/donör eşlemesi bu pakette yok | QC sonrası sağlıklı frontal korteks referansı |

Veriler `StopLaris_Final_Oncesi_Tam_Calisma_Paketi.zip` içinden hazırlanmıştır. `data/provenance.json` kaynak dosyaların SHA-256 değerlerini ve dönüşümleri; `data/metadata.json` veri seti, skor ve analiz katmanı tanımlarını korur. Kaynak arşivdeki tarihsel V4 sonuçları güncel V5 yerine kullanılmaz. Ana kohortun UMAP koordinatları özgün RDS nesnesinden alınmıştır; eksik kohort koordinatları uydurulmaz.

Bu sürüm mevcut model çıktılarını görüntüler. Yeni CSV için model eğitimi veya yeni hasta tahmini çalıştırmaz. CSV yüklemeleri yalnızca ilgili oturumun hücre keşfine eklenir. Orijinal veri dosyaları değiştirilmez.

## Bilimsel kapsam

Ana modelin hedefi marker kökenli hücre etiketleridir. `iCAF_like_uncertain`, `myCAF_like` ve `pericyte_vCAF_like` etiketleri belirsizlikleriyle birlikte korunur. Hasta başına makro F1 ortalaması, tüm hücrelerden hesaplanan makro F1 ile aynı ölçüt değildir. Dış aktarımın marker referans uyumu bağımsız uzman altın standardı veya klinik doğrulama değildir. Sağlıklı referansta USP9X pozitifliği QC sonrasında **809/10.253** hücredir; bu değer klinik güvenlilik kanıtı oluşturmaz.

Geliştirme kohortundaki **FibroScore1**, dış kohorttaki **inflammatory_iCAF_z**, **contractile_myCAF_z** ve **stromal_perivascular_z** özgün araştırma ölçümleridir. Birbirlerinin yerine kullanılamaz. Hasta tanısı, prognozu, tedavi önerisi veya deneysel olarak doğrulanmış USP9X mekanizması üretilmez.

## Yeniden doğrulama

```r
install.packages("testthat", repos = "https://cloud.r-project.org")
```

```sh
Rscript tests/run_tests.R
```

Test çıktıları `validation/` klasöründe, tarayıcı ekran görüntüleri aynı klasördeki PNG dosyalarındadır. Testler kohort sayıları, kaynak UMAP kapsamı, sağlıklı referans sayımı, model karışıklık matrisi toplamları, filtreleme, veri yükleme doğrulaması ve indirmeleri kapsar. Bunlar uygulamanın yazılım testleridir; önceki makine öğrenmesi validasyon deneylerine eklenerek tek bir klinik doğrulama sayısı oluşturulmaz.

Kaynak veri paketinden tekrar hazırlama:

```sh
python scripts/prepare_data.py --help
```

Bu işlem için kaynak arşivin çıkarılmış hâli ve betikte listelenen Python bağımlılıkları gerekir. Normal kullanımda `data/` hazırdır, Python gerekmez.

## Resmî belgeler

- [R kurulumu](https://www.r-project.org/)
- [Shiny for R](https://shiny.posit.co/r/getstarted/shiny-basics/lesson1/)
- [Shiny reaktif sunucu testleri](https://shiny.posit.co/r/reference/shiny/latest/testserver.html)
- [Shiny dosya indirme işlevi](https://shiny.posit.co/r/reference/shiny/latest/downloadhandler.html)

Bu paket, İP-7'nin araştırma prototipi kapsamını karşılamak üzere hazırlanmıştır. İnternette yayın, klinik kullanım ve bağımsız biyolojik doğrulama bu yazılım tesliminden ayrı işlemlerdir.
