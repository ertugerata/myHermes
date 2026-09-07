# SKILL NAME: PDF Summarizer & Smart Shelf Organizer

## TRIGGER / SCHEDULE:
- Her gün 08:30 ve 23:00'te otomatik tetiklenir veya manuel olarak istendiğinde çalıştırılır.

## TARGET DIRECTORY (WebDAV / Local Dizin):
- Okuma Listesi: `/Bilgi_Tabani/02_Okuma_Listesi/`
- Akıllı Raflar Ana Dizin: `/Bilgi_Tabani/03_Akilli_Raflar/`

---

## WORKFLOW & INSTRUCTIONS:

### 1. Dosya Tespit ve Tarama Adımı
1. `/Bilgi_Tabani/02_Okuma_Listesi/` klasörünü tara.
2. Klasör içerisindeki yeni işlenmemiş `.pdf` ve döküman dosyalarını tespit et.
3. Eğer klasör boşsa işlemi sonlandır ve log kaydı oluştur (`İşlenecek yeni dosya bulunamadı.`).

### 2. Okuma ve Derin Analiz Adımı
Tespit edilen her bir döküman için:
1. Dökümanın tamamını oku ve içeriğini analiz et.
2. İçeriğin ana konusunu, odak alanını ve teknik/akademik kategorisini belirle.
   - Örnek Kategoriler: `#Yazilim`, `#Finans`, `#Saglik`, `#Yapay_Zekai`, `#Tarih_Edebiyat`, `#Egitim`, `#Hukuk_Mevzuat` vb.
   - Eğer uygun bir kategori yoksa, konu başlığına uygun yeni bir `#Kategori` klasörü adı tanımla.

### 3. Türkçe Akademik Özet Raporu Üretme (.md)
Her döküman için orijinal dosya adıyla aynı isimde bir Markdown özet dosyası üret (Örn: `Rapor_Adı_Ozet.md`).

Rapor aşağıdaki standart şablona sahip olmalıdır:

```markdown
# 📑 Döküman Özet Raporu: [Orijinal Dosya Adı]

- **İşlenme Tarihi:** YYYY-AA-GG
- **Kategori / Raf:** #Kategori_Adı
- **Analiz Modeli:** [DEEP_RESEARCH_MODEL]

---

## 💡 Genel Özet
[Dökümanın ana fikrini ve amacını açıklayan 2-3 paragraflık akademik seviyede Türkçe özet]

## 📌 Kritik Çıkarımlar ve Önemli Noktalar
- **Çıkarım 1:** [Detaylı açıklama]
- **Çıkarım 2:** [Detaylı açıklama]
- **Çıkarım 3:** [Detaylı açıklama]

## 📊 Önemli Veri, Metrik ve Bulgular (Varsa)
- [Dökümanda geçen sayısal veriler, istatistikler, tarihler veya teknik parametreler]

## 🚀 Sonuç ve Değerlendirme
[Dökümanın sunduğu nihai sonuç veya öneriler]
```

### 4. Akıllı Raf Düzenleme ve Taşıma Adımı
1. Dökümanın belirlenen kategorisine denk gelen klasörü `/Bilgi_Tabani/03_Akilli_Raflar/#Kategori_Adı/` dizini altında oluştur veya var olanı kullan.
2. Üretilen Markdown özet raporunu (`.md`) ilgili kategori klasörüne yerleştir.
3. Orijinal PDF / döküman dosyasını `/Bilgi_Tabani/02_Okuma_Listesi/` dizininden alıp ilgili kategori klasörüne taşı.
