# MyHermes Projesi - Detaylı Kullanım Kılavuzu (USAGE.md)

Bu kılavuz, **Hermes Agent** web arayüzünün (Dashboard) Hugging Face Spaces veya yerel bir Docker ortamında nasıl kurulacağını, çalıştırılacağını, gelişmiş ağ (DNS) çözümlerini, güvenlik yapılandırmalarını, yedekleme mekanizmasını, **önceden yapılan ayarların ve verilerin nasıl korunduğunu (State Preservation)**, **`config.yaml` yapılandırmasının nasıl yüklendiğini**, **beceri (skills) klasörlerinin nasıl bağlandığını (volume)**, **`buzz-skills` (Kendi Özel Relay'iniz veya Genel Relay) kullanımı** ve **`mcuadros/ofelia` zamanlayıcısı ile otomatik görev çalıştırmayı** detaylandırmaktadır.

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

---

## 🐝 `buzz-skills` Entegrasyonu ve Esnek Relay Kullanımı (Kendi Relay'iniz ya da Genel Relay)

Projeye Git Submodule olarak eklenen `buzz-skills` (`https://github.com/tonbistudio/buzz-skills`), Hermes Agent'ın Buzz platformu (Nostr tabanlı mesajlaşma ağı) ile iletişim kurmasını sağlar.

Hermes Agent'ı ister **kendi kurduğunuz (Self-Hosted) bir Buzz Relay'e**, ister **mevcut bir genel/topluluk (Public) Relay'e** bağlayabilirsiniz.

### 1. Relay Bağlantı Yöntemleri ve Ayarlar

Relay URL adresini 2 farklı yöntemle kolayca tanımlayabilirsiniz:

#### Yöntem A: `.env` / Çevre Değişkeni Kullanarak (`BUZZ_RELAY_URL`)
`.env` dosyanıza `BUZZ_RELAY_URL` değişkenini ekleyerek başlangıçta dinamik olarak atanmasını sağlayabilirsiniz:

- **Seçenek 1: Kendi Kurduğunuz Yerel Relay (Self-Hosted):**
  ```env
  BUZZ_RELAY_URL="ws://localhost:8080"
  # veya Docker ağı içerisindeki bir relay için:
  # BUZZ_RELAY_URL="ws://buzz-relay:8080"
  # veya IP üzerinden:
  # BUZZ_RELAY_URL="ws://192.168.1.50:8080"
  ```

- **Seçenek 2: Mevcut Genel Topluluk Relay'i (Public / Community):**
  ```env
  BUZZ_RELAY_URL="wss://relay.buzz.community"
  ```

#### Yöntem B: `config.yaml` veya `hermes config set` Kullanarak
DOğrudan `config.yaml` içinden `gateway.platforms.buzz.extra.relay_url` alanını düzenleyebilirsiniz:

```yaml
gateway:
  platforms:
    buzz:
      enabled: true
      extra:
        relay_url: "ws://localhost:8080"         # Kendi relay'iniz veya wss://relay.buzz.community
        cli_path: "/usr/local/bin/buzz"           # Buzz CLI binary yolu
        channels: ["<CHANNEL_UUID>"]              # Dinlenecek kanal ID'leri
        home_channel: "<HOME_CHANNEL_UUID>"       # Bildirim kanalı ID'si
        require_mention: true                      # Etiketlenince yanıt ver
        allow_all_users: false                    # Yalnızca izinli kullanıcılara yanıt ver
        allowed_users: ["<OWNER_NPUB>"]           # İzin verilen kullanıcı adresi
```

### 2. Kimlik Bilgileri (`.env`)
```env
BUZZ_PRIVATE_KEY="nsec1..."      # Dedicated agent private key
BUZZ_AUTH_TAG='["auth", ...]'    # NIP-OA attestation tag (Gerekli ise)
```

### 3. PDF Summarizer İçinde Otomatik Bildirim
`pdf-summarizer` skill'i çalıştığında belirlenen bu relay adresi (`relay_url`) üzerinden ilgili Buzz kanalına Türkçe özet raporunun tamamlandığı bildirimini otomatik gönderir.

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

---

## Yerel Ortamda Docker ile Çalıştırma

### Docker Compose ile Çalıştırma (Ofelia Zamanlayıcı Dahil - Önerilen):
```bash
# Submodule'leri çekin
git submodule update --init --recursive

# Docker Compose ile Hermes ve Ofelia servislerini başlatın
docker-compose up -d --build
```
