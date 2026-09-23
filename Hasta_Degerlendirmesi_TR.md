# StopLaris — Hasta değerlendirmesi

Bu bölüm, paket içindeki GSE173278 kohortuna ait 10 hastanın **USP9X göreli ifade indeksini (0–10)** gösterir. Bu sürümde klinik risk hesaplanamaz: nüks, sağkalım veya tedavi yanıtına ait hasta sonlanımları ve bu sonlanımlar için doğrulanmış bir model bulunmaz.

## Kullanım

1. **Hasta değerlendirmesi** sekmesini açın.
2. Paket içindeki hasta kimliklerinden birini seçin.
3. İndeksi, ortalama USP9X değerini, hücre ve örnek sayısını birlikte inceleyin.
4. Hastanın kohorttaki konumunu ve hücre etiketi dağılımını görün; hasta özetini CSV olarak indirin.

Hücre keşfi filtreleri ve yüklenen CSV dosyaları bu bölümün sabit referansını değiştirmez. Yeni yüklenen hastalara klinik tahmin veya bu indeks atanmaz. Dış kohort ve sağlıklı referans, ölçüm ve örnekleme farkları nedeniyle bu sıralamaya katılmaz.

## İndeksin hesabı

Her hasta için pakette tutulan tüm hücrelerin `USP9X` değerlerinin aritmetik ortalaması alınır. Bu alan hücre bazında **log1p(CP10K)** ölçeğindedir. Logaritması alınmış hücre değerlerinin ortalaması, toplu sayımlardan hesaplanan bir pseudobulk ekspresyon ölçüsü değildir.

On hastanın ortalamaları küçükten büyüğe sıralanır. Eşit ortalamalar ortalama sıra numarasını paylaşır.

`İndeks = 10 × (sıra − 1) / (hasta sayısı − 1)`

En küçük ortalama 0, en büyük ortalama 10 olur. Tüm değerler eşitse indeks 5'tir. İndeks, yalnızca bu referanstaki sıralamayı anlatır; bir olasılık, etki büyüklüğü veya klinik eşik değildir. Örneğin **10/10, %100 hastalık riski anlamına gelmez**; 0/10 da hastalıksız veya risksiz olmayı göstermez.

Referans: `GSE173278`, `V5_STAGE2_2026-09-20`, 842 hücre, 10 hasta. Mevcut CAF/KİF sınıflandırıcısının F1 değerleri bu yeni betimsel indeksin klinik doğrulaması değildir.

## Yorumlama sınırları

- Hasta başına hücre sayısı 6 ile 352 arasında değişir. Özellikle 6 hücreli JK126 için en yüksek sıra, güvenilir bir klinik sonuç ya da güçlü kanıt anlamına gelmez. Sıralama örneklem büyüklüğü veya ölçüm belirsizliğine göre düzeltilmemiştir.
- Birden çok kaynak örnek/bölge ve hücre etiketinin karışımı ortalamayı etkileyebilir. Her hücre eşit ağırlık alır; örnekler eşit ağırlıklandırılmaz. Sonuç tek bir biyopsinin standartlaştırılmış testi değildir.
- Pozitif hücre oranı, ölçülen USP9X değeri sıfırdan büyük hücrelerin oranıdır; kanser pozitifliği değildir.
- İfade düzeyi tek başına USP9X'in nedensel rolünü, TNT/TM mekanizmasını veya bir tedavinin yararını göstermez. Otomatik tedavi önerisi ve düşük/orta/yüksek klinik risk sınıfı üretilmez.

## Klinik risk modeline geçiş için gerekenler

Önce hedef klinik sonuç ve zaman aralığı belirlenmelidir; örneğin belirli bir zaman ufkunda nüks. Uygun takip verileri, ölçüm protokolü ve eksik veri kurallarıyla geliştirilmiş modelin hasta düzeyinde ayrılmış verilerde ayırt etme, kalibrasyon ve klinik yarar değerlendirmeleri yapılmalıdır. Bunlar mevcut hücre etiketi sınıflandırma sonuçlarından türetilemez.

Yöntem ayrımına ilişkin birincil kaynaklar (erişim: 22 Eylül 2026):

- [TRIPOD+AI kontrol listesi](https://www.tripod-statement.org/wp-content/uploads/2019/12/TRIPODAI_checklist.pdf): hedef popülasyon, sonlanım, zaman ufku, model çıktısı ve performans değerlendirmesinin açık raporlanması.
- [FDA–NIH biyobelirteç terminolojisi](https://www.fda.gov/drugs/biomarker-qualification-program/transcript-biomarker-terminology-speaking-same-language): moleküler ölçüm ile klinik olayı öngören prognostik biyobelirteç kullanımının ayrımı.

Bu kaynaklar StopLaris indeksinin onayı veya doğrulaması değildir; indeks bu yazılımda eklenen keşifsel bir özetleme yöntemidir.
