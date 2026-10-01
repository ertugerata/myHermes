# SKILL NAME: PDF Summarizer & Smart Shelf Organizer

## TRIGGER / SCHEDULE:
- Her gün 08:30 ve 23:00'te otomatik tetiklenir veya manuel olarak istendiğinde çalıştırılır.

## TARGET DIRECTORY CONFIGURATION (Hedef Dizin Yapılandırması):
Bu beceri hem **Yerel Klasör (Local)** hem de **WebDAV Sunucusu** üzerindeki dizinleri dinamik olarak takip edebilir. Takip edilecek dizin türü ve yolları çevre değişkenleri (Environment Variables) veya `.env` dosyası üzerinden yapılandırılır.
Varsayılan klasör yapısı (`/Bilgi_Tabani/02_Okuma_Listesi/` ve `/Bilgi_Tabani/03_Akilli_Raflar/`) sistem başlangıcında otomatik olarak oluşturulur ve doğrulanır.

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

#### 3. Open Notebook Bilgi Tabanı MCP Ayarları (ÖNCELİKLİ HEDEF):
Open Notebook (https://github.com/lfnovo/open-notebook) ayrı bir IP/ağ üzerinde çalışır ve Model Context Protocol (MCP) vasıtasıyla entegre olur. **Open Notebook, bu becerinin birincil (öncelikli) bilgi tabanı ve çıktı merkezidir.** Döküman özetleri,notlar ve kaynaklar öncelikli olarak Open Notebook'a aktarılır ve tüm çıktılar onun üzerinden alınır/sorgulanır.
- **`OPEN_NOTEBOOK_URL`**: Open Notebook API sunucu adresi (Örn: `http://192.168.1.100:5055` veya `http://<OPEN_NOTEBOOK_IP>:5055`). Varsayılan: `http://localhost:5055`
- **`OPEN_NOTEBOOK_PASSWORD`**: Open Notebook API kimlik doğrulama şifresi/anahtarı (Varsa)
- **`PDF_SUMMARIZER_OPEN_NOTEBOOK_NOTEBOOK`**: Hedef defter ana adı (Varsayılan: `Bilgi Tabani`)
- **`PDF_SUMMARIZER_OPEN_NOTEBOOK_ENABLED`**: Open Notebook MCP entegrasyonu aktifliği (`true`/`false`). Varsayılan: `true`

---

## DEPOLAMA YARDIMCISI KULLANIMI (`storage_helper.py`):
Hermes Agent bu beceriyi çalıştırırken, Yerel veya WebDAV fark etmeksizin dosya işlemlerini ve klasör yapısı kurulumunu otomatik yöneten yardımcı betiği kullanabilir:

```bash
# Gerekli bağımlılıkları kontrol etme/kurma ve dizinleri ilklendirip hazırlama (Başlangıç Kurulumu):
python3 skills/pdf-summarizer/storage_helper.py setup

# Sadece bağımlılıkları kontrol etme:
python3 skills/pdf-summarizer/storage_helper.py check-deps

# Öntanımlı okuma listesi ve raf klasör yapılarını otomatik oluşturma/ilklendirme:
python3 skills/pdf-summarizer/storage_helper.py init-dirs

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

# Open Notebook MCP bilgi tabanı durumunu kontrol etme:
python3 skills/pdf-summarizer/storage_helper.py open-notebook-status

# Özet raporu ve dökümanı Open Notebook bilgi tabanına senkronize etme (ÖNCELİKLİ ADIM):
python3 skills/pdf-summarizer/storage_helper.py sync-open-notebook "/tmp/Rapor_Adi_Ozet.md" "Yazilim" --doc-file "/tmp/Rapor_Adi.pdf"

# Open Notebook üzerindeki kayıtlı notları/özetleri listeleme:
python3 skills/pdf-summarizer/storage_helper.py open-notebook-notes

# Open Notebook üzerindeki tekil not içeriğini çekme:
python3 skills/pdf-summarizer/storage_helper.py open-notebook-get-note "<NOTE_ID>"

# Open Notebook bilgi tabanında vektör araması yapma:
python3 skills/pdf-summarizer/storage_helper.py search-open-notebook "Yapay zeka uygulamaları"

# Open Notebook bilgi tabanına soru sorma:
python3 skills/pdf-summarizer/storage_helper.py ask-open-notebook "Raporlardaki ana bulgular nelerdir?"
```

---

## WORKFLOW & INSTRUCTIONS:

### 0. Bağımlılık ve Dizin Kurulum Adımı (Başlangıç Hazırlığı)
1. Skill çağırıldığında veya çalıştırıldığında ilk iş olarak `python3 skills/pdf-summarizer/storage_helper.py setup` komutunu çalıştır.
2. Bu komut, döküman işleme ve depolama için gerekli Python paketlerinin (`httpx`, `pypdf`, `pdfplumber`, `python-docx`) ve hedef depolama dizinlerinin kurulu olduğunu doğrulayacak, eksik paketleri otomatik olarak kuracaktır.

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

### 4. Open Notebook Bilgi Tabanı Aktarımı (ÖNCELİKLİ MCP ADIMI)
1. Üretilen akademik özet raporunu ve orijinal dökümanı **öncelikli olarak** Open Notebook MCP sunucusuna aktar:
   `python3 skills/pdf-summarizer/storage_helper.py sync-open-notebook "/tmp/Rapor_Adı_Ozet.md" "Kategori_Adı" --doc-file "/tmp/Rapor_Adı.pdf"`
2. Çıktıları ve kayıtlı notları Open Notebook MCP üzerinden sorgula/çek:
   - Notları listeleme: `python3 skills/pdf-summarizer/storage_helper.py open-notebook-notes`
   - Not detayını alma: `python3 skills/pdf-summarizer/storage_helper.py open-notebook-get-note "<NOTE_ID>"`
   - Bilgi tabanında arama yapma: `python3 skills/pdf-summarizer/storage_helper.py search-open-notebook "<ARAMA_SORGUSU>"`
   - Bilgi tabanına soru sorma: `python3 skills/pdf-summarizer/storage_helper.py ask-open-notebook "<SORU>"`

### 5. Yedek Dizin ve Raf Düzenleme Adımı (Yerel / WebDAV)
1. Üretilen Markdown özet raporunu yedek kategori rafına yükle/kaydet:
   `python3 skills/pdf-summarizer/storage_helper.py upload-summary "/tmp/Rapor_Adı_Ozet.md" "Kategori_Adı" "Rapor_Adı_Ozet.md"`
2. Orijinal PDF / döküman dosyasını okuma listesinden kategori rafına taşı:
   `python3 skills/pdf-summarizer/storage_helper.py move-to-shelf "Rapor_Adı.pdf" "Kategori_Adı"`

### 6. Bildirim Gönderme (Buzz Kanalı)
1. Özetleme ve raf düzenleme işlemleri tamamlandıktan sonra, özet raporunun hazırlandığına dair bir bildirim mesajı oluştur.
2. Bildirim mesajında dosya adı, kategori rafı, işlenme tarihi ve kısa özet bilgisi yer almalıdır.
3. Bu bildirimi **Buzz kanalı** (hermes-in-buzz / buzz-skills) üzerinden ilgili kanala / kullanıcıya gönder.
