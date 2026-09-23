# Kaynaklar ve yeniden kullanım notları

## Proje kodu

Bu hazırlık sürümünde proje kodu için ayrı bir açık kaynak lisansı seçilmemiştir. Depoya erişim, bu belgenin vermediği ek bir yeniden kullanım izni olarak sunulmaz. Kullanım koşulları için proje ekibiyle iletişime geçilmelidir.

## Araştırma verileri

`data/` klasörü, aşağıdaki kamuya açık GEO serilerinden hazırlanan seçilmiş/türetilmiş hücre tablolarını, kaynak kayıtlarını ve proje analiz sonuçlarını içerir:

- [GSE173278](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE173278)
- [GSE141946](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE141946)
- [GSE97930](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE97930)

Bu paket tam ham dizileme verilerinin bir kopyası değildir. Kontrollü erişim gerektiren EGA/FASTQ/BAM verileri bu pakette bulunmaz. Hangi kaynak dosyalardan hangi dönüşümlerin yapıldığı `data/provenance.json`, `data/sources.csv` ve `data/metadata.json` içinde kayıtlıdır.

Verilerin yeniden kullanımı sırasında kaynak çalışmalar ve ilgili veri erişim kayıtları belirtilmelidir. NCBI, moleküler verilerin kullanımı/dağıtımı için kendisinin kısıtlama koymadığını; buna karşılık göndericilerin tüm fikrî haklarını devredemeyeceğini veya garanti edemeyeceğini açıklar. Bu depodaki kod için ileride seçilecek bir lisans üçüncü taraf verilerine otomatik olarak uygulanmaz.

- [NCBI Molecular Data Usage politikası](https://www.ncbi.nlm.nih.gov/home/about/policies/)
- [GEO kullanım ve sorumluluk açıklaması](https://www.ncbi.nlm.nih.gov/geo/info/disclaimer.html)

## Logo ve bağımlılıklar

`www/stoplaris-logo.png`, proje ekibi tarafından sağlanan özgün logo dosyasıdır. Bu depo logonun yeniden kullanımına ilişkin ayrı bir izin beyanı içermez.

R, Shiny, ggplot2, DT ve jsonlite bu depoda yeniden dağıtılmaz; kullanıcı tarafından kendi dağıtım kanallarından kurulur ve kendi lisans koşullarına tabidir.
