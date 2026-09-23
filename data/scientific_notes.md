# Bilimsel yorum sınırları

- Geliştirme: 842 hücre, 10 hasta. Ana metrik hasta ortalama makro-F1 = 0,8840518603780836; birleşik hücre makro-F1 = 0,9231877906547575. Bu ölçüler farklı ağırlıklandırmalarla hesaplanır.
- Ana OOF çıktıda her hücrenin hastası eğitim dışında tutulmuştur. Kalibrasyon ikincil analizdir. Mevcut etiketlerin yeniden tahmini bağımsız CAF alt tipi doğrulaması değildir.
- Permütasyon: 1.000 gerçek farklı koşu, aşım 0, artı-bir p = 1/1001 = 0,000999000999. Test yalnız kalibrasyonsuz geniş-grid hasta ortalama F1 istatistiğine aittir.
- Dış aktarım: 1.404 stromal aday, üç donör, dört kaynak örnek. Marker referansına makro-F1 0,37972798540827163; bağımsız uzman altın standardı ve klinik doğrulama yok. Dataset-ayırma AUC değeri CAF başarısı değildir.
- GSE97930 sağlıklı QC sonrası 10.253 hücrenin 809'unda USP9X > 0. Kaynak sınıf önekleri korunmuştur; donör kimliği çıkarılmamıştır.
- Geliştirme USP9X log-normalizasyon paydası 24.715 kaynak genin toplamıdır. Dış ifade görselleştirmesinin paydası tüm dış kütüphane toplamıdır; dış model olasılıkları kayıtlı V5 aligned-input normalizasyonunu korur. Sağlıklı payda min.cells=3 filtresinden sonraki toplamdır. Veri kümeleri arasında doğrudan etki/ekspresyon farkı testi yapılmaz.
- Güncel kaynakta emCAF/iCAF/myCAF için ortak üç program skoru yoktur. FibroScore1 ve dış marker skorları özgün adlarıyla sunulur; pericyte_vCAF_like, emCAF diye yeniden adlandırılmaz.
- UMAP koordinatları kaynak Seurat nesnesinden hücre kimliğiyle 1:1 eşleştirilmiştir. Yeniden UMAP çalıştırılmamıştır. Dış ve sağlıklı kohort koordinatları boştur.
- USP9X hedeflemesi, tedavi yararı, nedensellik veya normal doku güvenliliği bu uygulamada gösterilmiş sayılmaz.
