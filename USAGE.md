# MyHermes Projesi - Detaylı Kullanım Kılavuzu (USAGE.md)

Bu kılavuz, **Hermes Agent** web arayüzünün (Dashboard) Hugging Face Spaces veya yerel bir Docker ortamında nasıl kurulacağını, çalıştırılacağını, gelişmiş ağ (DNS) çözümlerini, güvenlik yapılandırmalarını, yedekleme mekanizmasını, **önceden yapılan ayarların ve verilerin nasıl korunduğunu (State Preservation)**, **`config.yaml` yapılandırmasının nasıl yüklendiğini**, **beceri (skills) klasörlerinin nasıl bağlandığını (volume)**, **`buzz-skills` (Kendi Özel Relay'iniz veya Genel Relay) kullanımı**, **`pdf-summarizer` Dizin Yapılandırması (Local / WebDAV)** ve **`mcuadros/ofelia` zamanlayıcısı ile otomatik görev çalıştırmayı** detaylandırmaktadır.

---

## 🚀 Başlangıç ve Çalıştırma

Bu proje, Hermes Agent Dashboard'u bir Docker konteyneri içinde barındırır. Hugging Face Spaces veya yerel konteyner ortamlarında sorunsuz, yüksek performanslı ve güvenli çalışacak şekilde optimize edilmiştir.

### 🖥️ Web TUI (ttyd Terminali) ve Süreç Yönetimi (Supervisor)

Bu proje, Hermes Agent'ın TUI (Terminal Kullanıcı Arayüzü) ekranına web tarayıcınız üzerinden erişebilmenizi sağlayan **ttyd** (xterm.js tabanlı web terminali) entegrasyonuyla birlikte gelir. Tüm arka plan süreçleri, otomatik kurtarma, periyodik yedekleme ve sıralı başlatma özellikleri ise endüstriyel standarttaki **supervisord** süreç yöneticisi tarafından yönetilir.

#### 🔌 Sunulan Web Arayüzleri ve Erişim Portları

| Arayüz | Port | URL | Açıklama |
| :--- | :--- | :--- | :--- |
| **Kontrol Paneli (Dashboard)** | `7860` | `http://localhost:7860` | Web yönetim arayüzü, sohbet, eklentiler ve genel konfigürasyon. |
| **TUI Web Terminali** | `7861` | `http://localhost:7861` | Tarayıcı üzerinden tam özellikli terminal TUI (Kanban panosu, Temsilci listesi, Oturum geçmişi ve sistem widget'ları). |

> 💡 **Hugging Face Spaces Ayarı:** Hugging Face Spaces üzerinde dağıtırken her iki porttan da yararlanabilmek için **Settings -> Repository -> Ports** bölümüne `7860, 7861` portlarını eklediğinizden emin olun.

---

#### ⚙️ Supervisord Süreç Yapılandırması ve Sıralı Başlatma

Konteyner başlatıldığında supervisord, aşağıdaki süreçleri hiyerarşik öncelik (priority) değerlerine göre sırasıyla ve güvenli bir şekilde çalıştırır:

1. **`dns-resolve` (Öncelik: 10):** DoH (DNS-over-HTTPS) ön çözümleme servisini başlatarak engelli alan adlarını tespit eder.
2. **`github-restore` (Öncelik: 20):** Başlangıçta varsa GitHub üzerindeki `.hermes` yedeklerinizi geri yükler.
3. **`auth-config` (Öncelik: 30):** Çevre değişkenlerinden gelen dashboard giriş bilgilerini, Buzz platform ayarlarını ve kimlik doğrulama eklentisini güvenle hazırlar.
4. **`hermes-dashboard` (Öncelik: 40):** 7860 portunda çalışacak olan ana kontrol panelini ayağa kaldırır.
5. **`hermes-tui-web` (Öncelik: 50):** 7861 portu üzerinden ttyd terminali ile `hermes --tui` TUI arayüzünü tarayıcılara sunar.
6. **`backup-loop` (Öncelik: 60):** Her 2 saatte bir değişen verileri algılayarak GitHub yedek deposuna push eder.

---

#### 🔍 Konteyner İçi Doğrulama ve Durum Takibi

Konteyner içerisinde hangi süreçlerin aktif olarak çalıştığını veya loglarını anlık izlemek için:

```bash
# Tüm servislerin durumunu kontrol edin
supervisorctl status

# Belirli bir servisin durumunu veya loglarını izleyin
supervisorctl tail -f hermes-tui-web
supervisorctl tail -f hermes-dashboard
```

---

## 🛡️ Önceden Yapılan Ayarların ve Verilerin Korunması (State Preservation)

Hermes Agent üzerinde yaptığınız özelleştirmelerin, geçmiş sohbet verilerinin, kayıtlı ayarların (`config.yaml`), API anahtarlarının ve yüklenen becerilerin (skills) korunması şu 3 temel mekanizma ile garanti altına alınır:

### 1. Veri Saklama Yöntemi Seçimi (Data Volume vs. Local Directory)
Kurulum sihirbazı (`scripts/setup-wizard.sh`) veya `hermes-start` betiği üzerinden verilerinizin saklanacağı yöntemi seçebilirsiniz:
- **Seçenek A: Yerel Ev Dizini (Local Host Directory - `$HOME/.hermes`):**
  Host makinenizdeki `~/.hermes` dizinini konteyner içindeki `/home/user/.hermes` konumuna bağlar. Konteyner silinse veya baştan derlense dahi verileriniz bilgisayarınızda kalıcı olarak saklanır.
- **Seçenek B: Docker Hacmi (Docker Named Volume - `hermes-data`):**
  Docker tarafından yönetilen izole bir hacim kullanılır. Konteyner güncellemelerinde veri kaybı yaşanmaz.

### 2. GitHub Otomatik Yedekleme ve Geri Yükleme (Automatic Backup & Restore)
Konteyner her başlatıldığında `scripts/start.sh` önceden yapılandırılmış GitHub yedek deponuzdan (`GITHUB_BACKUP_REPO` ve `GITHUB_TOKEN`) verileri indirir.
- `.hermes` veritabanı, oturum geçmişleri ve `config.yaml` dosyası otomatik geri yüklenir.
- Sistem her 2 saatte bir ve konteyner durdurulurken (`SIGTERM`) güncel durumu GitHub deponuza geri push eder.

### 3. Versiyon Güncelleme Entegrasyonu (`scripts/update-version.sh`)
Uygulama sürümünü güncellerken verilerinizin veya özelleştirilmiş ayarlarınızın silinmesi söz konusu değildir:
- `VERSION.txt` dosyası üzerinden Hermes imaj sürümü güncellenir.
- `scripts/update-version.sh` betiği `Dockerfile` içerisindeki `ARG HERMES_VERSION` değerini günceller.
- Konteyner yeniden derlendiğinde (`docker-compose up -d --build` veya `docker build`), verileriniz bağlı olan hacim (`$HOME/.hermes` veya `hermes-data`) ya da GitHub yedeği sayesinde **birebir korunarak aktarılır**.

---

## 🧙‍♂️ İnteraktif Kurulum Sihirbazı Entegrasyonu (`scripts/setup-wizard.sh`)

Sihirbaz betiği, veri koruma tercihleriniz ile zamanlayıcı servislerini tek bir akışta entegre eder:

```bash
./scripts/setup-wizard.sh
```

Sihirbaz şu adımları otomatik yönetir:
1. **Hedef Ortam Seçimi:** Hugging Face Spaces veya Yerel Docker.
2. **Kimlik Doğrulama & API Key Tanımlama:** `.env` dosyasına güvenli kayıt.
3. **GitHub Yedekleme Kurulumu:** Otomatik geri yükleme/yedekleme bağlantısı.
4. **PDF Summarizer Dizin Yapılandırması:** Yerel Klasör (Local) veya WebDAV Sunucu seçimi.
5. **Veri Saklama Yöntemi Seçimi:** `$HOME/.hermes` (Yerel dizin) veya `hermes-data` (Docker Hacmi).
6. **Otomatik Çalıştırma Tercihi:**
   - **Docker Compose (Önerilen):** Hermes Agent ve `mcuadros/ofelia` zamanlayıcısını birlikte başlatır.
   - **Docker run:** Sadece Hermes Agent konteynerini başlatır.

---

## 📄 `config.yaml` Yapılandırma Dosyası Nasıl Yüklenir ve Dağıtılır?

Hermes Agent çalışma zamanında konfigürasyon dosyasını varsayılan olarak `~/.hermes/config.yaml` (ve `~/.config/hermes/config.yaml`) konumunda arar. Projede `config.yaml` dosyasının sisteme yüklenmesi ve güncel tutulması şu mimari akışla gerçekleşir:

1. **Kaynak Tanımı (`CONFIG_SRC`):**
   - `Dockerfile` içerisinde `CONFIG_SRC=/home/user/app/config.yaml` çevre değişkeni tanımlanmıştır.
2. **İmaj Derleme Aşaması (Build Time):**
   - `Dockerfile` derlenirken kök dizindeki `config.yaml` hem `$HOME/.config/hermes/config.yaml` hem de `$HOME/.hermes/config.yaml` dizinlerine kopyalanır.
3. **Başlangıç ve Dinamik Güncelleme (Runtime Distribution):**
   - Konteyner ayağa kalkarken `scripts/start.sh` betiği çalışır.
   - Betik önce `auth-config.py` ile çevre değişkenlerini (şifreler, auth eklentisi durumu, API anahtarları, Buzz platform ayarları) `config.yaml` üzerine işler.
   - Ardından `config.yaml` dosyasını sistemdeki aktif konfigürasyon hedeflerine dinamik olarak dağıtır:
     - `/home/user/.hermes/config.yaml`
     - `/home/user/.config/hermes/config.yaml`
   - Eğer GitHub yedekleme sistemi aktif ise ve depoda önceden kaydedilmiş bir `config.yaml` bulunuyorsa, restore işlemi sırasında bu dosya indirilir ve yine aynı hedeflere kopyalanarak uygulamanın özelleştirilmiş ayarları korunur.

---

## 🔒 Güvenlik ve Dinamik Kimlik Doğrulama (Authentication)

Dış dünyaya açık (kamusal IP'ye veya `0.0.0.0` adresine bağlanan) tüm Hermes Dashboard arayüzlerinde kimlik doğrulama yapılması zorunludur. Geçerli bir kimlik doğrulama sağlayıcısı yapılandırılmadığı takdirde dashboard güvenlik amacıyla başlatılmayacaktır.

> ⚠️ **Önemli Bilgi:** `--insecure` parametresi artık pasiftir (deprecated / no-op) ve dışarıya açık bağlantılarda kimlik doğrulamayı devre dışı bırakmaz. Kamusal bağlantılarda her zaman geçerli bir kimlik doğrulama sağlayıcısı bulunmalıdır. Bu nedenle, gereksiz yük oluşturmaması ve uyarı vermemesi amacıyla `scripts/start.sh` dosyasından tamamen kaldırılmıştır.

---

## 🌐 Gelişmiş Ağ ve DNS-over-HTTPS (DoH) Çözümü

Hugging Face Spaces gibi kısıtlı konteyner ortamlarında, Telegram, WhatsApp, Slack, Discord ve bazı yapay zeka (AI) sağlayıcılarının (OpenAI, Anthropic vb.) alan adları varsayılan DNS sunucuları tarafından engellenebilir veya çözümlenemeyebilir.

Bu sorunu aşmak için projeye **DNS-over-HTTPS (DoH)** tabanlı dinamik bir bypass mekanizması entegre edilmiştir.

---

## 📁 `pdf-summarizer` Skill Dizin Yapılandırması (Local vs. WebDAV)

`pdf-summarizer` skill'i dökümanları **Yerel Klasör (Local Directory)** veya **WebDAV Sunucusu** üzerinden okuyup düzenleyebilir. Hangi dizinin takip edileceği çevre değişkenleri üzerinden belirlenir. Uygulama başlatıldığında öntanımlı okuma listesi ve raf klasör yapıları otomatik ilklendirilir.

### Çevre Değişkenleri:

| Değişken Adı | Türü | Varsayılan | Açıklama |
| :--- | :--- | :--- | :--- |
| `PDF_SUMMARIZER_TARGET_TYPE` | Değişken | `local` | Takip türü: `local` veya `webdav` |
| `PDF_SUMMARIZER_LOCAL_READING_LIST` | Değişken | `/Bilgi_Tabani/02_Okuma_Listesi` | Yerel okuma listesi dizini |
| `PDF_SUMMARIZER_LOCAL_SHELVES` | Değişken | `/Bilgi_Tabani/03_Akilli_Raflar` | Yerel akıllı raflar dizini |
| `PDF_SUMMARIZER_WEBDAV_URL` | Değişken | *(Boş)* | WebDAV sunucu adresi (Örn: `https://dav.example.com/remote.php/dav/files/user`) |
| `PDF_SUMMARIZER_WEBDAV_USERNAME` | Değişken | *(Boş)* | WebDAV kullanıcı adı |
| `PDF_SUMMARIZER_WEBDAV_PASSWORD` | Sır (Secret) | *(Boş)* | WebDAV şifresi veya uygulama anahtarı |
| `PDF_SUMMARIZER_WEBDAV_READING_LIST` | Değişken | `/Bilgi_Tabani/02_Okuma_Listesi` | WebDAV okuma listesi klasör yolu |
| `PDF_SUMMARIZER_WEBDAV_SHELVES` | Değişken | `/Bilgi_Tabani/03_Akilli_Raflar` | WebDAV akıllı raflar klasör yolu |

### Depolama Yardımcısı (`storage_helper.py`):
Skill içerisinde dosya listeleme, indirme, yükleme, taşıma ve varsayılan klasör yapısını ilklendirme işlemleri `skills/pdf-summarizer/storage_helper.py` betiği ile yönetilir:

```bash
# Öntanımlı klasör yapısını manuel oluşturma/doğrulama:
python3 skills/pdf-summarizer/storage_helper.py init-dirs

# Depolama durumunu ve bağlantıyı test etme:
python3 skills/pdf-summarizer/storage_helper.py status

# Okuma listesini listeleme:
python3 skills/pdf-summarizer/storage_helper.py list
```

---

## 💾 GitHub ile Otomatik Yedekleme ve Geri Yükleme (Backup & Restore)

Uygulamanın oturum geçmişi, veritabanı ve ayarları (`.hermes` dizini ve `config.yaml` dosyası) Hugging Face Spaces gibi geçici (ephemeral) ortamlarda konteyner sıfırlandığında kaybolabilir. Bunu önlemek için **GitHub tabanlı dinamik yedekleme ve geri yükleme** mekanizması (`scripts/github-backup.sh`) eklenmiştir.

---

## 🛠️ Sorun Giderme ve Log Dosyaları (Troubleshooting)

Hugging Face Spaces üzerinde başlangıç gecikmelerini, yedekleme hatalarını veya bağlantı sorunlarını gidermek için sistemdeki kritik geçici log dosyalarını inceleyebilirsiniz:

* **`/tmp/git_clone.log`**: Başlangıçta yedek deposunun GitHub'dan klonlanması sırasında oluşan tüm hata ve çıktıları içerir.
* **`/tmp/git_push.log`**: Yedeklerin periyodik veya graceful shutdown sırasında GitHub deposuna push edilmesi esnasındaki tüm detayları barındırır.
* **`/tmp/dns-resolved.json`**: DNS-over-HTTPS (DoH) ile çözümlenmiş güncel alan adı / IP adres eşleştirmelerini gösterir.
* **`backup.log` (veya `$HOME/app/backup.log`)**: Tüm yedekleme ve geri yükleme geçmişini etiketli ve zaman damgalı (`INFO`, `SUCCESS`, `WARNING`, `ERROR`) olarak listeler.

---

## 🔑 Çevre Değişkenleri (Environment Variables) ve Sırlar (Secrets)

Uygulamanın çalışması için aşağıdaki değişkenler kullanılmaktadır. Bunları Hugging Face Spaces ayarlarında **Variables** veya **Secrets** olarak tanımlayabilirsiniz.

### 1. Kimlik Doğrulama Değişkenleri

| Değişken Adı | Türü | Varsayılan | Açıklama |
| :--- | :--- | :--- | :--- |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | Değişken/Sır | `admin` | Dashboard arayüzüne giriş kullanıcı adı. |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | Sır (Secret) | *(Otomatik Üretilir)* | Giriş şifresi. Belirtilmezse, başlangıçta rastgele üretilir ve loglara basılır. Bu değer `config.yaml` içindeki eski şifreleri ezer. |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH` | Sır (Secret) | *(Boş)* | Şifrenin düz metin olarak girilmesini istemiyorsanız, önceden üretilmiş `scrypt` hash değerini buraya tanımlayabilirsiniz. |

### 2. Buzz Kanalı ve Bildirim Değişkenleri

| Değişken Adı | Türü | Varsayılan | Açıklama |
| :--- | :--- | :--- | :--- |
| `BUZZ_ENABLE` | Değişken | `false` | Buzz entegrasyonunu açıkça aktifleştirmek için `true` yapın. |
| `BUZZ_RELAY_URL` | Değişken/Sır | `wss://relay.buzz.community` | Bağlanılacak Buzz Relay adresi (Örn: `ws://localhost:8080` veya `wss://relay.buzz.community`). |
| `BUZZ_PRIVATE_KEY` | Sır (Secret) | *(Boş)* | Dedicated agent private key (`nsec1...`). |
| `BUZZ_HOME_CHANNEL` | Değişken | *(Boş)* | PDF özet ve otomatik bildirimlerin gönderileceği ana Buzz kanal ID'si (UUID). |
| `BUZZ_CHANNELS` | Değişken | *(Boş)* | Dinlenecek Buzz kanallarının virgülle veya JSON dizisi olarak listesi. |
| `BUZZ_CLI_PATH` | Değişken | `/usr/local/bin/buzz` | Buzz CLI ikili dosyasının yolu. |
| `BUZZ_ALLOWED_USERS` | Değişken | *(Boş)* | Komut çalıştırmasına izin verilen kullanıcı adresi (`npub1...` veya hex). |
| `BUZZ_ALLOW_ALL_USERS` | Değişken | `false` | Tüm kullanıcıların komut tetiklemesine izin vermek için `true` yapın. |

### 3. Yapay Zeka (AI) API Anahtarları
Kullanmak istediğiniz modellere göre ilgili sağlayıcıların API anahtarlarını **Secret** olarak ekleyin:
- **OpenAI:** `OPENAI_API_KEY`
- **Anthropic:** `ANTHROPIC_API_KEY`
- **OpenRouter:** `OPENROUTER_API_KEY`
- **DeepSeek:** `DEEPSEEK_API_KEY`
- **Groq:** `GROQ_API_KEY`

### 4. GitHub Yedekleme Değişkenleri

| Değişken Adı | Türü | Varsayılan | Açıklama |
| :--- | :--- | :--- | :--- |
| `GITHUB_BACKUP_REPO` | Değişken/Sır | *(Boş)* | Yedeklerin saklanacağı GitHub deposunun adresi. |
| `GITHUB_TOKEN` | Sır (Secret) | *(Boş)* | GitHub deposuna yazma yetkisi olan kişisel erişim token'ı (PAT). |

---

## 🐝 `buzz-skills` Entegrasyonu ve Otomatik Platform Yapılandırması

`scripts/auth-config.py` betiği, yukarıdaki Buzz çevre değişkenlerini tespit ettiğinde `config.yaml` dosyasında Buzz platformunu otomatik olarak **etkinleştirir (`enabled: true`)** ve tüm alanları günceller:

```yaml
gateway:
  platforms:
    buzz:
      enabled: true
      extra:
        relay_url: "ws://localhost:8080"         # BUZZ_RELAY_URL
        cli_path: "/usr/local/bin/buzz"           # BUZZ_CLI_PATH
        channels: ["<CHANNEL_UUID>"]              # BUZZ_CHANNELS
        home_channel: "<HOME_CHANNEL_UUID>"       # BUZZ_HOME_CHANNEL
        require_mention: true                     # BUZZ_REQUIRE_MENTION
        allow_all_users: false                    # BUZZ_ALLOW_ALL_USERS
        allowed_users: ["<OWNER_NPUB>"]           # BUZZ_ALLOWED_USERS
```

Bu sayede, `BUZZ_RELAY_URL` veya `BUZZ_HOME_CHANNEL` tanımlandığında `pdf-summarizer` skill'inin 5. adımındaki Buzz kanalı bildirimi **kullanıcının `config.yaml` dosyasını elle düzenlemesine gerek kalmadan tam otomatik olarak çalışır**.

---

## 🛠️ Beceri (Skills) Yönetimi ve Volume Bağlantıları

Hermes Agent'ın becerileri (skills) algılaması ve harici beceri depolarını sorunsuz çalıştırabilmesi için volume ve konfigürasyon entegrasyonu yapılmıştır.

### Skill Klasörlerinin Volume Olarak Tanımlanması (`docker-compose.yml`)
Yerel geliştirme ve konteyner ortamında yeni becerilerin anında algılanması ve kod değişikliklerinin konteyner içine yansıması için `docker-compose.yml` içerisinde klasörler volume olarak bağlanmıştır:

```yaml
version: '3'

services:
  hermes:
    build: .
    container_name: hermes-agent
    ports:
      - "7860:7860"
      - "7861:7861"
    volumes:
      - hermes-data:/home/user/.hermes
      - ./skills:/home/user/app/skills
      - ./buzz-skills:/home/user/app/buzz-skills
    restart: always

  ofelia:
    image: mcuadros/ofelia:v0.3.22
    container_name: ofelia-scheduler
    depends_on:
      - hermes
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./ofelia.conf:/etc/ofelia/config.ini:ro
    restart: always

volumes:
  hermes-data:
```

---

## ⏰ `mcuadros/ofelia` Zamanlayıcı ve PDF Summarizer Otomasyonu

İşlemleri zamanlanmış görev (Cron) olarak çalıştırmak amacıyla `mcuadros/ofelia` Docker konteyneri entegre edilmiştir.

### 📅 Zamanlama Konfigürasyonu (`ofelia.conf`)
Ofelia, `/var/run/docker.sock` üzerinden `hermes-agent` konteynerinde doğrudan komut çalıştırır:

```ini
[global]

[job-exec "pdf-summarizer-morning"]
schedule = 0 30 8 * * *
container = hermes-agent
command = /opt/hermes/.venv/bin/hermes run --skill pdf-summarizer "PDF Summarizer & Smart Shelf Organizer skill'ini çalıştır"

[job-exec "pdf-summarizer-evening"]
schedule = 0 0 23 * * *
container = hermes-agent
command = /opt/hermes/.venv/bin/hermes run --skill pdf-summarizer "PDF Summarizer & Smart Shelf Organizer skill'ini çalıştır"
```

### 📄 PDF Summarizer & Smart Shelf Organizer İş Akışı:
1. **Dosya Tarama:** `/Bilgi_Tabani/02_Okuma_Listesi/` (veya yapılandırılmış WebDAV/Yerel dizin) altındaki yeni PDF/dökümanları tespit eder.
2. **Derin Analiz & Türkçe Özet:** Dökümanı analiz edip standart şablon ile akademik Türkçe özet `.md` raporu oluşturur.
3. **Akıllı Raf Düzenleme:** Dosyayı ve özetini `/Bilgi_Tabani/03_Akilli_Raflar/#Kategori_Adı/` dizinine (Local veya WebDAV) taşır.
4. **Buzz Kanalı Bildirimi:** Özet tamamlandığında hazırlanan özetin durumunu **Buzz kanalı** (`hermes-in-buzz`) üzerinden kullanıcıya bildirir.

---

## Yerel Ortamda Docker ile Çalıştırma

### Docker Compose ile Çalıştırma (Ofelia Zamanlayıcı Dahil - Önerilen):
```bash
# Submodule'leri çekin
git submodule update --init --recursive

# Docker Compose ile Hermes ve Ofelia servislerini başlatın
docker-compose up -d --build
```
