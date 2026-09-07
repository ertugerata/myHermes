# MyHermes Projesi - Detaylı Kullanım Kılavuzu (USAGE.md)

Bu kılavuz, **Hermes Agent** web arayüzünün (Dashboard) Hugging Face Spaces veya yerel bir Docker ortamında nasıl kurulacağını, çalıştırılacağını, gelişmiş ağ (DNS) çözümlerini, güvenlik yapılandırmalarını, yedekleme mekanizmasını, **`config.yaml` yapılandırmasının nasıl yüklendiğini**, **beceri (skills) klasörlerinin nasıl bağlandığını (volume)** ve **`mcuadros/ofelia` zamanlayıcısı ile otomatik görev çalıştırmayı** detaylandırmaktadır.

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
3. **`auth-config` (Öncelik: 30):** Çevre değişkenlerinden gelen dashboard giriş bilgilerini ve kimlik doğrulama eklentisini güvenle hazırlar.
4. **`hermes-dashboard` (Öncelik: 40):** 7860 portunda çalışacak olan ana kontrol panelini ayağa kaldırır.
5. **`hermes-tui-web` (Öncelik: 50):** 7861 portu üzerinden ttyd terminali ile `hermes --tui` TUI arayüzünü tarayıcılara sunar.
6. **`backup-loop` (Öncelik: 60):** Her 2 saatte bir değişen verileri algılayarak GitHub yedek deposuna push eder.

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

## 🛠️ Beceri (Skills) Yönetimi, Volume Bağlantıları ve `buzz-skills` Entegrasyonu

Hermes Agent'ın becerileri (skills) algılaması ve harici beceri depolarını sorunsuz çalıştırabilmesi için volume ve konfigürasyon entegrasyonu yapılmıştır.

### 1. Skill Klasörlerinin Volume Olarak Tanımlanması (`docker-compose.yml`)
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

### 2. Harici Skill Dizinlerinin `config.yaml` ile Tanımlanması
Hermes Agent'ın bu dizinlerdeki tüm becerileri tarayabilmesi için `config.yaml` içindeki `skills.external_dirs` alanına hedefler eklenmiştir:

```yaml
skills:
  creation_nudge_interval: 15
  disabled: []
  external_dirs:
  - /home/user/app/skills
  - /home/user/.hermes/skills
  - /home/user/app/buzz-skills
  - /home/user/.hermes/skills/buzz-skills
```

### 3. Git Submodule Entegrasyonu (`buzz-skills`)
`buzz-skills` reposu projeye bir Git submodule olarak eklenmiştir (`.gitmodules`):
```ini
[submodule "buzz-skills"]
	path = buzz-skills
	url = https://github.com/tonbistudio/buzz-skills
```
Bu sayede `git submodule update --init --recursive` komutu ile tüm Buzz becerileri otomatik çekilir ve `docker-compose` volume bağlantısı sayesinde Hermes Agent tarafından anında kullanılabilir hale gelir.

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
4. **Buzz Kanalı Bildirimi:** Özet tamamlandığında hazırlanan özetin durumunu **Buzz kanalı** üzerinden kullanıcıya bildirir.

---

## 🧙‍♂️ İnteraktif Kurulum Sihirbazı (Önerilen)
Konteynerinizi çalıştırmadan önce tüm ayarlarınızı interaktif ve kolay bir şekilde yapılandırmak isterseniz, sizin için hazırladığımız Türkçe kurulum sihirbazını yerel ortamınızda çalıştırabilirsiniz:
```bash
./scripts/setup-wizard.sh
```

---

## Yerel Ortamda Docker ile Çalıştırma

### Docker Compose ile Çalıştırma (Ofelia Zamanlayıcı Dahil - Önerilen):
```bash
# Submodule'leri çekin
git submodule update --init --recursive

# Docker Compose ile Hermes ve Ofelia servislerini başlatın
docker-compose up -d
```

---

## 🔒 Güvenlik ve Dinamik Kimlik Doğrulama (Authentication)

Dış dünyaya açık (kamusal IP'ye veya `0.0.0.0` adresine bağlanan) tüm Hermes Dashboard arayüzlerinde kimlik doğrulama yapılması zorunludur.

---

## 🌐 Gelişmiş Ağ ve DNS-over-HTTPS (DoH) Çözümü

Hugging Face Spaces gibi kısıtlı konteyner ortamlarında engelli alan adlarını aşmak için DoH çözümü otomatik devreye girer.

---

## 💾 GitHub ile Otomatik Yedekleme ve Geri Yükleme (Backup & Restore)

Uygulamanın oturum geçmişi, veritabanı ve ayarları (`.hermes` dizini ve `config.yaml` dosyası) GitHub depolarına otomatik yedeklenir.

---

## 🔑 Çevre Değişkenleri (Environment Variables) ve Sırlar (Secrets)

Uygulamanın çalışması için gerekli çevre değişkenleri ve API anahtarları hakkında detaylı bilgiler yukarıdaki bölümlerde açıklanmıştır.
