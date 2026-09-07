# MyHermes Projesi - Detaylı Kullanım Kılavuzu (USAGE.md)

Bu kılavuz, **Hermes Agent** web arayüzünün (Dashboard) Hugging Face Spaces veya yerel bir Docker ortamında nasıl kurulacağını, çalıştırılacağını, gelişmiş ağ (DNS) çözümlerini, güvenlik yapılandırmalarını, yedekleme mekanizmasını, **önceden yapılan ayarların ve verilerin nasıl korunduğunu (State Preservation)**, **`config.yaml` yapılandırmasının nasıl yüklendiğini**, **beceri (skills) klasörlerinin nasıl bağlandığını (volume)**, **`buzz-skills` entegrasyonu ve kullanımını** ve **`mcuadros/ofelia` zamanlayıcısı ile otomatik görev çalıştırmayı** detaylandırmaktadır.

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

## 🚀 Başlangıç ve Çalıştırma

Bu proje, Hermes Agent Dashboard'u bir Docker konteyneri içinde barındırır. Hugging Face Spaces veya yerel konteyner ortamlarında sorunsuz, yüksek performanslı ve güvenli çalışacak şekilde optimize edilmiştir.

### 🖥️ Web TUI (ttyd Terminali) ve Süreç Yönetimi (Supervisor)

Bu proje, Hermes Agent'ın TUI (Terminal Kullanıcı Arayüzü) ekranına web tarayıcınız üzerinden erişebilmenizi sağlayan **ttyd** (xterm.js tabanlı web terminali) entegrasyonuyla birlikte gelir. Tüm arka plan süreçleri, otomatik kurtarma, periyodik yedekleme ve sıralı başlatma özellikleri ise endüstriyel standarttaki **supervisord** süreç yöneticisi tarafından yönetilir.

#### 🔌 Sunulan Web Arayüzleri ve Erişim Portları

| Arayüz | Port | URL | Açıklama |
| :--- | :--- | :--- | :--- |
| **Kontrol Paneli (Dashboard)** | `7860` | `http://localhost:7860` | Web yönetim arayüzü, sohbet, eklentiler ve genel konfigürasyon. |
| **TUI Web Terminali** | `7861` | `http://localhost:7861` | Tarayıcı üzerinden tam özellikli terminal TUI (Kanban panosu, Temsilci listesi, Oturum geçmişi ve sistem widget'ları). |

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
4. **Veri Saklama Yöntemi Seçimi:** `$HOME/.hermes` (Yerel dizin) veya `hermes-data` (Docker Hacmi).
5. **Otomatik Çalıştırma Tercihi:**
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
   - Betik önce `auth-config.py` ile çevre değişkenlerini (şifreler, auth eklentisi durumu, API anahtarları) `config.yaml` üzerine işler.
   - Ardından `config.yaml` dosyasını sistemdeki aktif konfigürasyon hedeflerine dinamik olarak dağıtır:
     - `/home/user/.hermes/config.yaml`
     - `/home/user/.config/hermes/config.yaml`
   - Eğer GitHub yedekleme sistemi aktif ise ve depoda önceden kaydedilmiş bir `config.yaml` bulunuyorsa, restore işlemi sırasında bu dosya indirilir ve yine aynı hedeflere kopyalanarak uygulamanın özelleştirilmiş ayarları korunur.

---

## 🐝 `buzz-skills` Entegrasyonu ve Hermes Tarafından Kullanımı

Projeye Git Submodule olarak eklenen `buzz-skills` (`https://github.com/tonbistudio/buzz-skills`), Hermes Agent'ın Buzz platformu (Nostr tabanlı mesajlaşma ağı) ile uçtan uca haberleşmesini, medya eklentilerini ve bildirimleri yönetmesini sağlar.

### 1. `buzz-skills` İçeriği ve Beceriler
- **`hermes-in-buzz`**: Hermes Agent gateway'ini Buzz relay ağına bağlar, gelen mesajları dinler ve yanıtlar üretir.
- **`buzz-media-attachments`**: Buzz mesajlarındaki medya dosyalarını ve ekleri işler.
- **`buzz-self-hosting`**: Kendi Buzz relay ve sunucu altyapınızı barındırma yönergelerini içerir.

### 2. Hermes Tarafından Otomatik Algılanması
`docker-compose.yml` içinde `./buzz-skills` klasörü hem `/home/user/app/buzz-skills` hem de `/home/user/.hermes/skills/buzz-skills` konumlarına volume olarak bağlanmıştır. Ayrıca `config.yaml` dosyasında `skills.external_dirs` altına eklenmiştir:

```yaml
skills:
  external_dirs:
  - /home/user/app/buzz-skills
  - /home/user/.hermes/skills/buzz-skills
```

### 3. Gerekli Ayarlar ve Yapılandırma

Buzz entegrasyonunun çalışması için gereken ayarlar `config.yaml` veya `.env` dosyası üzerinden şu şekilde tanımlanır:

#### A. Konfigürasyon Ayarları (`config.yaml` veya `hermes config set`):
```yaml
gateway:
  platforms:
    buzz:
      enabled: true
      extra:
        relay_url: "wss://relay.buzz.community"  # Buzz Relay adresi
        cli_path: "/usr/local/bin/buzz"           # Buzz CLI binary yolu
        channels: ["<CHANNEL_UUID>"]              # Dinlenecek kanal ID'leri
        home_channel: "<HOME_CHANNEL_UUID>"       # Bildirimlerin gönderileceği ana kanal ID'si
        require_mention: true                      # Yalnızca etiketlenince yanıt ver
        allow_all_users: false                    # Sadece izinli kullanıcılara yanıt ver
        allowed_users: ["<OWNER_NPUB>"]           # İzin verilen kullanıcı npub/hex adresi
```

#### B. Kimlik Bilgileri ve Sırlar (`.env`):
Hermes Agent'ın Buzz üzerinde oturum açabilmesi için dedicated agent private key ve auth tag değerleri `.env` veya Hermes secrets içinde tanımlanır:
```env
BUZZ_PRIVATE_KEY="nsec1..."      # Ajanın özel anahtarı (Asla kişisel nsec kullanmayın!)
BUZZ_AUTH_TAG='["auth", ...]'    # NIP-OA attestation tag (Gerekli ise)
```

### 4. PDF Summarizer İçinde Buzz Kullanımı
`pdf-summarizer` skill'i çalışma sonunda özet hazırlandığında bildirim göndermek için Buzz altyapısını kullanır:
1. PDF özeti ve akıllı raf düzenleme işlemi biter.
2. Hermes Agent `hermes-in-buzz` kanalı üzerinden `gateway.platforms.buzz.extra.home_channel` veya ilgili kanala özet raporunun hazır olduğuna dair bildirim mesajı yayınlar.

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
      - ./skills:/home/user/.hermes/skills
      - ./skills:/home/user/app/skills
      - ./buzz-skills:/home/user/app/buzz-skills
      - ./buzz-skills:/home/user/.hermes/skills/buzz-skills
    restart: always

  ofelia:
    image: mcuadros/ofelia:latest
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
1. **Dosya Tarama:** `/Bilgi_Tabani/02_Okuma_Listesi/` altındaki yeni PDF/dökümanları tespit eder.
2. **Derin Analiz & Türkçe Özet:** Dökümanı analiz edip standart şablon ile akademik Türkçe özet `.md` raporu oluşturur.
3. **Akıllı Raf Düzenleme:** Dosyayı ve özetini `/Bilgi_Tabani/03_Akilli_Raflar/#Kategori_Adı/` dizinine taşır.
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
