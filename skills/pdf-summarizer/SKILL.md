# SKILL NAME: PDF Summarizer & Smart Shelf Organizer

## TRIGGER / SCHEDULE:
- Her gün 08:30 ve 23:00'te otomatik tetiklenir veya manuel olarak istendiğinde çalıştırılır.

## TARGET DIRECTORY CONFIGURATION (Hedef Dizin Yapılandırması):
Bu beceri hem **Yerel Klasör (Local)** hem de **WebDAV Sunucusu** üzerindeki dizinleri dinamik olarak takip edebilir. Takip edilecek dizin türü ve yolları çevre değişkenleri (Environment Variables) veya `.env` dosyası üzerinden yapılandırılır.

### Çevre Değişkenleri Yapılandırması:
- **`PDF_SUMMARIZER_TARGET_TYPE`**: Saklama/takip türü (`local` veya `webdav`). Varsayılan: `local`

#### 1. Yerel Klasör (Local) Ayarları (`PDF_SUMMARIZER_TARGET_TYPE=local`):
- **`PDF_SUMMARIZER_LOCAL_READING_LIST`**: Okuma listesi dizini (Varsayılan: `/Bilgi_Tabani/02_Okuma_Listesi/`)
- **`PDF_SUMMARIZER_LOCAL_SHELVES`**: Akıllı raflar ana dizini (Varsayılan: `/Bilgi_Tabani/03_Akilli_Raflar/`)

#### 2. WebDAV Sunucusu Ayarları (`PDF_SUMMARIZER_TARGET_TYPE=webdav`):
- **`PDF_SUMMARIZER_WEBDAV_URL`**: WebDAV sunucu adresi (Örn: `https://dav.example.com/remote.php/dav/files/user/`)
- **`PDF_SUMMARIZER_WEBDAV_USERNAME`**: WebDAV kullanıcı adı
- **`PDF_SUMMARIZER_WEBDAV_PASSWORD`**: WebDAV şifresi veya uygulama anahtarı
- **`PDF_SUMMARIZER_WEBDAV_READING_LIST`**: WebDAV okuma listesi yolu (Varsayılan: `/Bilgi_Tabani/02_Okuma_Listesi/`)
- **`PDF_SUMMARIZER_WEBDAV_SHELVES`**: WebDAV akıllı raflar ana dizin yolu (Varsayılan: `/Bilgi_Tabani/03_Akilli_Raflar/`)

---

## DEPOLAMA YARDIMCISI KULLANIMI (`storage_helper.py`):
Hermes Agent bu beceriyi çalıştırırken, Yerel veya WebDAV fark etmeksizin dosya işlemlerini otomatik yöneten yardımcı betiği kullanabilir:

```bash
# Mevcut konfigürasyonu ve bağlantıyı kontrol etme:
python3 skills/pdf-summarizer/storage_helper.py status

# Okuma listesindeki dökümanları listeleme (JSON formatında):
python3 skills/pdf-summarizer/storage_helper.py list

# Dökümanı yerel geçici çalışma dizinine indirme/kopyalama:
python3 skills/pdf-summarizer/storage_helper.py download "Rapor_Adi.pdf" "/tmp/Rapor_Adi.pdf"

# Kategori raf klasörünü oluşturma/doğrulama:
python3 skills/pdf-summarizer/storage_helper.py ensure-shelf "Yazilim"

# Hazırlanan özet raporunu (.md) kategori rafına yükleme/kaydetme:
python3 skills/pdf-summarizer/storage_helper.py upload-summary "/tmp/Rapor_Adi_Ozet.md" "Yazilim" "Rapor_Adi_Ozet.md"

# Orijinal PDF dosyasını okuma listesinden kategori rafına taşıma:
python3 skills/pdf-summarizer/storage_helper.py move-to-shelf "Rapor_Adi.pdf" "Yazilim"
```

---

## WORKFLOW & INSTRUCTIONS:

### 1. Dosya Tespit ve Tarama Adımı
1. `python3 skills/pdf-summarizer/storage_helper.py list` komutunu çalıştırarak okuma listesindeki işlenecek `.pdf`, `.doc`, `.docx` dökümanlarını tespit et.
2. Eğer liste boşsa işlemi sonlandır ve log kaydı oluştur (`İşlenecek yeni dosya bulunamadı.`).

### 2. Okuma ve Derin Analiz Adımı
Tespit edilen her bir döküman için:
1. Dökümanı `python3 skills/pdf-summarizer/storage_helper.py download "<DOSYA_ADI>" "/tmp/<DOSYA_ADI>"` ile geçici dizine al.
2. Dökümanın tamamını oku ve içeriğini analiz et.
3. İçeriğin ana konusunu, odak alanını ve teknik/akademik kategorisini belirle.
   - Örnek Kategoriler: `Yazilim`, `Finans`, `Saglik`, `Yapay_Zekai`, `Tarih_Edebiyat`, `Egitim`, `Hukuk_Mevzuat` vb.
   - Eğer uygun bir kategori yoksa, konu başlığına uygun yeni bir `Kategori_Adı` tanımla.

### 3. Türkçe Akademik Özet Raporu Üretme (.md)
Her döküman için orijinal dosya adıyla aynı isimde bir Markdown özet dosyası üret (Örn: `/tmp/Rapor_Adı_Ozet.md`).

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
1. Üretilen Markdown özet raporunu kategori rafına yükle/kaydet:
   `python3 skills/pdf-summarizer/storage_helper.py upload-summary "/tmp/Rapor_Adı_Ozet.md" "Kategori_Adı" "Rapor_Adı_Ozet.md"`
2. Orijinal PDF / döküman dosyasını okuma listesinden kategori rafına taşı:
   `python3 skills/pdf-summarizer/storage_helper.py move-to-shelf "Rapor_Adı.pdf" "Kategori_Adı"`

### 5. Bildirim Gönderme (Buzz Kanalı)
1. Özetleme ve raf düzenleme işlemleri tamamlandıktan sonra, özet raporunun hazırlandığına dair bir bildirim mesajı oluştur.
2. Bildirim mesajında dosya adı, kategori rafı, işlenme tarihi ve kısa özet bilgisi yer almalıdır.
3. Bu bildirimi **Buzz kanalı** (hermes-in-buzz / buzz-skills) üzerinden ilgili kanala / kullanıcıya gönder.
