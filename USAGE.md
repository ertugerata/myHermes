# MyHermes Projesi - Detaylı Kullanım Kılavuzu (USAGE.md)

Bu kılavuz, **Hermes Agent** web arayüzünün (Dashboard) yerel bir ortamda veya herhangi bir sunucuda (Docker / Docker Compose) nasıl kurulacağını, çalıştırılacağını, güvenlik yapılandırmalarını, yedekleme mekanizmasını, **önceden yapılan ayarların ve verilerin nasıl korunduğunu (State Preservation)**, **`config.yaml` yapılandırmasının nasıl yüklendiğini**, **beceri (skills) klasörlerinin nasıl bağlandığını (volume)**, **`buzz-skills` kullanımı**, **`pdf-summarizer` Dizin Yapılandırması (Local / WebDAV)** ve **`mcuadros/ofelia` zamanlayıcısı ile otomatik görev çalıştırmayı** detaylandırmaktadır.

---

## 📌 Son Güncellemeler ve Yapılan Değişiklikler

1. **Hugging Face Bağımlılıklarının Temizlenmesi:**
   - Hugging Face Spaces entegrasyonu, DoH DNS çözümleyicileri ve Hugging Face bağımlılıkları projeden temizlenmiş; sistem yerel ve sunucu dağıtımları için optimize edilmiştir.

2. **`ttyd` ve Web TUI Entegrasyonunun Kaldırılması:**
   - Artık ihtiyaç duyulmayan `ttyd` bağımlılığı ve buna bağlı olarak `7861` portu projeden kaldırılmıştır.
   - Sistem sadece ana web kontrol paneline (`7860` portu) odaklanmıştır.

3. **İnteraktif Kurulum Sihirbazı (`setup-wizard.sh`) Açıklamaları:**
   - İnteraktif `.env` yapılandırması oluşturan kurulum sihirbazı güncellenmiştir.

4. **`pdf-summarizer` Otomatik Bağımlılık ve Kurulum Yönetimi:**
   - `pdf-summarizer` skill'inin çalışması için gereken döküman okuma/işleme kütüphaneleri (`pypdf`, `pdfplumber`, `python-docx`) `requirements.txt` dosyasına eklenmiştir.

---

## 🚀 Başlangıç ve Çalıştırma

Bu proje, Hermes Agent Dashboard'u bir Docker konteyneri içinde barındırır. Yerel konteyner veya sunucu ortamlarında sorunsuz, yüksek performanslı ve güvenli çalışacak şekilde optimize edilmiştir.

### ⚙️ Süreç Yönetimi (Supervisor) ve Servis Hiyerarşisi

Bu projede tüm arka plan süreçleri, otomatik kurtarma, periyodik yedekleme ve sıralı başlatma özellikleri **supervisord** süreç yöneticisi tarafından yönetilir.

#### 🔌 Sunulan Web Arayüzü ve Erişim Portu

| Arayüz | Port | URL | Açıklama |
| :--- | :--- | :--- | :--- |
| **Kontrol Paneli (Dashboard)** | `7860` | `http://localhost:7860` | Web yönetim arayüzü, sohbet, eklentiler ve genel konfigürasyon. |

---

#### ⚙️ Supervisord Süreç Yapılandırması ve Sıralı Başlatma

Konteyner başlatıldığında supervisord, aşağıdaki süreçleri hiyerarşik öncelik (priority) değerlerine göre sırasıyla ve güvenli bir şekilde çalıştırır:

1. **`github-restore` (Öncelik: 20):** Başlangıçta varsa GitHub üzerindeki `.hermes` yedeklerinizi geri yükler.
2. **`auth-config` (Öncelik: 30):** Çevre değişkenlerinden gelen dashboard giriş bilgilerini, Buzz platform ayarlarını ve kimlik doğrulama eklentisini güvenle hazırlar.
3. **`hermes-dashboard` (Öncelik: 40):** 7860 portunda çalışacak olan ana kontrol panelini ayağa kaldırır.
4. **`ofelia` (Öncelik: 50):** Konteyner içinde zamanlanmış görevleri (`job-local`) yöneten Ofelia cron zamanlayıcısını çalıştırır.
5. **`backup-loop` (Öncelik: 60):** `BACKUP_INTERVAL` ile belirlenen aralıklarla (varsayılan: 7200 saniye / 2 saat) değişen verileri algılayarak GitHub yedek deposuna push eder.

---

#### 🔍 Konteyner İçi Doğrulama ve Durum Takibi

Konteyner içerisinde hangi süreçlerin aktif olarak çalıştığını veya loglarını anlık izlemek için:

```bash
# Tüm servislerin durumunu kontrol edin
supervisorctl status

# Dashboard servisini izleyin
supervisorctl tail -f hermes-dashboard
```

---

## 🛡️ Önceden Yapılan Ayarların ve Verilerin Korunması (State Preservation)

Hermes Agent üzerinde yaptığınız özelleştirmelerin, geçmiş sohbet verilerinin, kayıtlı ayarların (`config.yaml`), API anahtarlarının ve yüklenen becerilerin (skills) korunması şu temel mekanizmalar ile garanti altına alınır:

### 1. Veri Saklama Yöntemi Seçimi
Kurulum sihirbazı (`scripts/setup-wizard.sh`) veya `hermes-start` betiği üzerinden verilerinizin saklanacağı yöntemi seçebilirsiniz:
- **Seçenek A: Yerel Ev Dizini (Local Host Directory - `$HOME/.hermes`):**
  Host makinenizdeki `~/.hermes` dizinini konteyner içindeki `/home/user/.hermes` konumuna bağlar. Konteyner silinse veya baştan derlense dahi verileriniz bilgisayarınızda kalıcı olarak saklanır.
- **Seçenek B: Docker Hacmi (Docker Named Volume - `hermes-data`):**
  Docker tarafından yönetilen izole bir hacim kullanılır. Konteyner güncellemelerinde veri kaybı yaşanmaz.

### 2. GitHub Otomatik Yedekleme ve Geri Yükleme (Automatic Backup & Restore)
Konteyner her başlatıldığında `scripts/start.sh` önceden yapılandırılmış GitHub yedek deponuzdan (`GITHUB_BACKUP_REPO` ve `GITHUB_TOKEN`) verileri indirir.
- `.hermes` veritabanı, oturum geçmişleri ve `config.yaml` dosyası otomatik geri yüklenir.
- Sistem belirlenen yedekleme aralığında (`BACKUP_INTERVAL`, varsayılan 2 saat) ve konteyner durdurulurken (`SIGTERM`) güncel durumu GitHub deponuza geri push eder.

---

## 🧙‍♂️ İnteraktif Kurulum Sihirbazı (`scripts/setup-wizard.sh`)

`setup-wizard.sh` betiği, Hermes Agent'ın ilk kurulumunda veya yerel başlatma esnasında (`./hermes-start wizard` veya `.env` dosyası bulunmadığında) kullanıcıyı adım adım yönlendirerek gerekli tüm sistem yapılandırmalarını güvenli ve hatasız bir şekilde oluşturur.

### ❓ Sihirbazın İşlevleri:
1. **Çevre Değişkenleri ve `.env` Dosyası Oluşturma:** Uygulamanın çalışması için gerekli API anahtarlarını, şifreleri ve port tanımlarını toplayarak `.env` dosyası üretir.
2. **Dashboard Güvenliği (Basic Auth):** Dış dünyaya veya ağa açık arayüzlerde zorunlu olan yönetici kullanıcı adı ve şifresini belirler.
3. **Yapay Zeka (AI) Sağlayıcı Entegrasyonları:** OpenRouter, OpenAI, Anthropic, DeepSeek, Groq vb. API anahtarlarını yapılandırır.
4. **GitHub Yedekleme & Kurtarma:** Sohbet geçmişi ve ayarların kaybolmaması için GitHub tabanlı otomatik yedekleme deposunu bağlar.
5. **PDF Summarizer Dizin Yapılandırması:** Yerel Klasör (`Bilgi_Tabani/...`) veya WebDAV sunucusu ayarlarını ilklendirir.

### Sihirbazı Çalıştırma:
```bash
# Doğrudan çalıştırma:
./scripts/setup-wizard.sh

# Veya hermes-start betiği üzerinden:
./hermes-start wizard
```

---

## 📄 `config.yaml` Yapılandırma Dosyası Nasıl Yüklenir ve Dağıtılır?

Hermes Agent çalışma zamanında konfigürasyon dosyasını varsayılan olarak `~/.hermes/config.yaml` (ve `~/.config/hermes/config.yaml`) konumunda arar:

1. **Kaynak Tanımı (`CONFIG_SRC`):** `CONFIG_SRC=/home/user/app/config.yaml`
2. **İmaj Derleme Aşaması (Build Time):** `config.yaml` ilgili dizinlere kopyalanır.
3. **Başlangıç ve Dinamik Güncelleme:** `scripts/start.sh` betiği `auth-config.py` ile çevre değişkenlerini `config.yaml` üzerine işler ve aktif hedeflere dağıtır.

---

## 🔑 Çevre Değişkenleri (Environment Variables)

.env dosyasında aşağıdaki değişkenler tanımlanabilir:

### 1. Kimlik Doğrulama Değişkenleri
- `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` (Varsayılan: `admin`)
- `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD`
- `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH`

### 2. Yapay Zeka (AI) API Anahtarları
- `OPENROUTER_API_KEY`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `DEEPSEEK_API_KEY`
- `GROQ_API_KEY`

### 3. GitHub Yedekleme Değişkenleri
- `GITHUB_BACKUP_REPO`
- `GITHUB_TOKEN`
- `BACKUP_INTERVAL`

---

## ⏰ Entegre `mcuadros/ofelia` Zamanlayıcı ve PDF Summarizer Otomasyonu

İşlemleri zamanlanmış görev (Cron) olarak çalıştırmak amacıyla `mcuadros/ofelia` binary'si doğrudan Dockerfile içerisine dahil edilmiş ve Supervisord tarafından yönetilmektedir. Artık ayrı bir sidecar konteyner veya `docker.sock` erişimine gerek duymadan tüm servisler (Dashboard, GitHub Yedekleme ve Ofelia) tek bir konteyner içinde çalışır.

### Yerel Ortamda Docker ile Çalıştırma:
```bash
# hermes-start betiği ile tek komutla çalıştırma:
./hermes-start

# Veya manuel olarak Submodule'leri çekip Docker Compose ile başlatma:
git submodule update --init --recursive
docker compose up -d --build
```
