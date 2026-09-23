# StopLaris v1.2.0 — kaynak sürüm notları

**Belge tarihi:** 23 Eylül 2026  
**Kaynak deposu:** [StopLaris/StopLaris-Shiny](https://github.com/StopLaris/StopLaris-Shiny)  
**Kaynak referansı:** `refs/tags/v1.2.0`

Bu notlar v1.2.0 kaynak içeriğini tanımlar. Depo erişimi, etiket/release oluşturulması ve CI çalıştırmalarına ilişkin doğrulanmış yayın kanıtları ayrı yayımlama raporunda tutulur; bu belge bu işlemlerin tamamlandığını ilan etmez.

## Kapsam

Bu sürüm, mevcut StopLaris araştırma uygulamasını final raporunda kaynak gösterilebilecek bir kod deposu olarak düzenler. Hazırlık; Türkçe ağırlıklı ana README, kurulum ve kullanım yönergeleri, sürümlü ekip atfı, yerel dosya dışlama kuralları ve R test iş akışını ekler. Güncel logo varlığı depo hazırlığının görsel kapsamındadır.

Hasta değerlendirmesi, önceki uygulamada bulunan sabit GSE173278 referansını kullanır: **10 hasta ve 842 hücre**. `USP9X_cohort_midrank_0_10_v1` yöntemi, hasta ortalamalarının sırasını 0–10 ölçeğine dönüştürür. **Bu değer klinik risk, nüks olasılığı veya sağkalım tahmini değildir.** Kullanıcı yüklemelerine yeni hasta skoru atanmaz.

## Doğrulama kaydı

22 Eylül 2026 tarihli v1.1.0 tesliminin paket içindeki kayıtları şunlardır:

| Kayıt | Sonuç |
|---|---:|
| R testleri | 13 test, 142 başarılı doğrulama |
| Tarayıcı kontrolleri | 74 başarılı kontrol |
| HTTP ve varlık kontrolleri | 23 başarılı kontrol |
| Masaüstü/mobil ekran görüntüleri | 8 |

Bu tablo tarihsel v1.1.0 sonuçlarıdır. 23 Eylül 2026 tarihinde v1.2.0 kodunda 13 R testi / 142 doğrulama yeniden geçti; 11 R dosyası ayrıştırıldı ve arayüz HTML çıktısında tek logo doğrulandı. [Yeni R kaydı](../validation/publication-r-checks-2026-09-23.json) ayrıdır. 23 Eylül tarihli bu yerel kayıt yeni tarayıcı testi veya GitHub Actions çalışması içermez. Yeni iş akışı, **Ubuntu 24.04 / R 4.4.3** üzerinde mevcut `tests/run_tests.R` dosyasını çalıştırmak üzere hazırlanmıştır. Tarihsel yerel ortam **R 4.3.3 / Shiny 1.8.0** kullanmıştır. Paket sürümleri kilitlenmediği için ortamlar birebir aynı değildir.

GitHub Actions iş akışı yalnızca `contents: read` izni ister; checkout kimlik bilgilerini kalıcılaştırmaz ve kullanıcı sırrı gerektirmez. Tarayıcı ve HTTP testleri için [ayrı yönergeler](../validation/BROWSER_QA_README.md) geçerlidir.

## Atıf

**StopLaris Proje Ekibi. (2026). StopLaris: R Shiny tek hücre araştırma platformu (Sürüm 1.2.0).**

Atıf metaverisi [CITATION.cff](../CITATION.cff) dosyasındadır. Kaynak deposu [StopLaris/StopLaris-Shiny](https://github.com/StopLaris/StopLaris-Shiny), sürüm referansı `refs/tags/v1.2.0` olarak tanımlanmıştır. DOI atanmış değildir. Release bağlantısı ve yayın tarihi doğrulanan harici yayımlama kaydında belgelenir.

Bu hazırlıkta yazılıma lisans atanmadı; lisans seçimi proje ekibine bırakıldı. Veri kökeni [provenance kaydı](../data/provenance.json) ve [bilimsel kapsam](../data/scientific_notes.md) üzerinden izlenebilir.
