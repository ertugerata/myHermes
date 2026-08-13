# MyHermes Projesi - Detaylı Kullanım Kılavuzu (USAGE.md)

Bu kılavuz, **Hermes Agent** web arayüzünün (Dashboard) Hugging Face Spaces veya yerel bir Docker ortamında nasıl kurulacağını, çalıştırılacağını, gelişmiş ağ (DNS) çözümlerini, güvenlik yapılandırmalarını, yedekleme mekanizmasını ve **gerekli API anahtarlarının nasıl tanımlanacağını** detaylandırmaktadır.

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

### 🧙‍♂️ İnteraktif Kurulum Sihirbazı (Önerilen)
Konteynerinizi çalıştırmadan önce tüm ayarlarınızı interaktif ve kolay bir şekilde yapılandırmak isterseniz, sizin için hazırladığımız Türkçe kurulum sihirbazını yerel ortamınızda çalıştırabilirsiniz:
```bash
./scripts/setup-wizard.sh
```
Bu sihirbaz size adım adım rehberlik ederek:
- Dashboard yönetici adı ve şifresi belirlemenizi (veya otomatik güvenli şifre üretilmesini),
- Gerekli tüm yapay zeka API anahtarlarını (OpenRouter, OpenAI, Anthropic, DeepSeek, Groq vb.) girmenizi,
- GitHub otomatik yedekleme sistemini (depo adresi, PAT token ve periyot) kolayca kurmanuzu sağlayacaktır.

Seçtiğiniz hedef ortama göre (Yerel Docker veya Hugging Face Spaces):
- **Hugging Face Spaces** için hangi Secret ve Variable değerlerini Hugging Face arayüzüne kopyalamanız gerektiğini gösteren şık bir rehber sunar.
- **Yerel Docker** için gerekli tüm değişkenleri otomatik olarak kök dizinde `.env` dosyasına yazar ve isteğinize bağlı olarak Docker imajını derleyip konteynerinizi arka planda anında çalıştırır.

---

### Yerel Ortamda Docker ile Çalıştırma
Yerel makinenizde test etmek veya çalıştırmak için aşağıdaki adımları takip edebilirsiniz:

1. **Sürümü Güncelleyin (Opsiyonel):**
   Uygulamanın çalışacağı temel Hermes imajının sürümünü değiştirmek isterseniz, proje kökündeki `VERSION.txt` dosyasını düzenleyin ve ardından `scripts/update-version.sh` betiğini çalıştırın:
   ```bash
   # VERSION.txt dosyasını dilediğiniz sürüm ile güncelleyin (Örn: v2026.7.20)
   ./scripts/update-version.sh
   ```
   Bu işlem, `Dockerfile` içindeki sürüm tanımını otomatik olarak güncelleyecektir. GitHub Actions (`hf-sync.yml`) iş akışı da `main` dalına yapılan push'larda bu işlemi otomatik olarak gerçekleştirir.

   > 💡 **GitHub API Oran Limiti (Rate Limit) Hatası Giderme:**
   > Eğer betiği çalıştırırken *"GitHub API'sine erişilemedi veya en son sürüm bilgisi alınamadı"* uyarısı alırsanız, bu durum anonim isteklerin saatlik sınırına ulaşıldığını gösterebilir. Çözüm için terminalde geçerli bir `GITHUB_TOKEN` veya `GH_TOKEN` tanımlayarak komutu tekrar çalıştırın:
   > ```bash
   > export GITHUB_TOKEN="ghp_senin_kisisel_erisim_tokenin"
   > ./scripts/update-version.sh
   > ```

2. **Docker İmajını Derleyin:**
   ```bash
   docker build -t my-hermes-agent .
   ```

3. **Konteyneri Başlatın (Veri Saklama Yönteminize Göre):**
   Verilerinizi yerel ev dizininizde mi yoksa izole bir Docker Named Volume içerisinde mi saklamak istediğinize göre aşağıdaki komutlardan birini seçebilirsiniz:

   * **Seçenek A: Yerel Ev Dizini (Önerilen - Host üzerindeki ~/.hermes klasörünü bağlar):**
     ```bash
     mkdir -p "$HOME/.hermes"
     docker run -d \
       -p 7860:7860 \
       -p 7861:7861 \
       -e OPENROUTER_API_KEY=... \
       -e HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin \
       -e HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=GucluBirSifre123! \
       -v "$HOME/.hermes:/home/user/.hermes" \
       my-hermes-agent
     ```

   * **Seçenek B: Docker Hacmi (hermes-data adında izole bir Docker Named Volume kullanır):**
     ```bash
     docker run -d \
       -p 7860:7860 \
       -p 7861:7861 \
       -e OPENROUTER_API_KEY=... \
       -e HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin \
       -e HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=GucluBirSifre123! \
       -v hermes-data:/home/user/.hermes \
       my-hermes-agent
     ```
   Ardından tarayıcınızda `http://localhost:7860` ile kontrol paneline, `http://localhost:7861` ile de Web TUI ekranına bağlanabilirsiniz.

---

## 🔒 Güvenlik ve Dinamik Kimlik Doğrulama (Authentication)

Dış dünyaya açık (kamusal IP'ye veya `0.0.0.0` adresine bağlanan) tüm Hermes Dashboard arayüzlerinde kimlik doğrulama yapılması zorunludur. Geçerli bir kimlik doğrulama sağlayıcısı yapılandırılmadığı takdirde dashboard güvenlik amacıyla başlatılmayacaktır.

> ⚠️ **Önemli Bilgi:** `--insecure` parametresi artık pasiftir (deprecated / no-op) ve dışarıya açık bağlantılarda kimlik doğrulamayı devre dışı bırakmaz. Kamusal bağlantılarda her zaman geçerli bir kimlik doğrulama sağlayıcısı bulunmalıdır. Bu nedenle, gereksiz yük oluşturmaması ve uyarı vermemesi amacıyla `scripts/start.sh` dosyasından tamamen kaldırılmıştır.

### 🛠️ Dinamik Kimlik Doğrulama Nasıl Çalışır?
Konteyner her başlatıldığında `scripts/start.sh` dosyası devreye girerek kimlik doğrulamayı şu adımlarla dinamik olarak yapılandırır:

1. **Şifre Algılama, Hash'leme ve Ezme (Override):**
   - Konteyner ortamında güvenlik sağlamak amacıyla, çevre değişkenleri üzerinden iletilen `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` veya `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH` değerleri, `config.yaml` dosyasında önceden kayıtlı veya geri yüklenmiş olabilecek tüm eski şifreleri **her zaman ezer (explicitly override)**.
   - Eğer `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` çevre değişkeni tanımlanmışsa, bu şifre Hermes Agent'ın yerleşik `plugins.dashboard_auth.basic.hash_password` aracı kullanılarak güvenli bir şekilde `scrypt` algoritması ile hash'lenir ve `config.yaml` dosyasındaki `password_hash` alanına yazılır.
   - Eğer doğrudan `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH` tanımlanmışsa, bu değer doğrudan kullanılır.
   - Eğer hiçbir şifre veya hash tanımlanmamışsa, sistem **otomatik olarak 12 karakterli güvenli bir şifre üretir**, bunu hash'ler ve başlangıç loglarında net bir şekilde görüntüler.

2. **Eklenti Aktivasyonu:**
   - Kimlik doğrulama sağlayıcısının kayıt hatası vermesini engellemek için `config.yaml` dosyasında `basic` eklentisi (basic auth) otomatik olarak aktifleştirilir. Bu doğrultuda eklenti `plugins.disabled` listesinde varsa temizlenir ve `plugins.enabled` listesine eklenir.

---

## 🌐 Gelişmiş Ağ ve DNS-over-HTTPS (DoH) Çözümü

Hugging Face Spaces gibi kısıtlı konteyner ortamlarında, Telegram, WhatsApp, Slack, Discord ve bazı yapay zeka (AI) sağlayıcılarının (OpenAI, Anthropic vb.) alan adları varsayılan DNS sunucuları tarafından engellenebilir veya çözümlenemeyebilir.

Bu sorunu aşmak için projeye **DNS-over-HTTPS (DoH)** tabanlı dinamik bir bypass mekanizması entegre edilmiştir.

### ⚙️ DoH Çözümleyici Nasıl Çalışır?
1. **Ön Çözümleme (`scripts/dns-resolve.py`):**
   - Başlangıçta arka planda çalıştırılır. Sistem DNS'i çalışmıyorsa Cloudflare (`1.1.1.1`) veya Google (`8.8.8.8`) DoH servislerini kullanarak engelli alan adlarının IP adreslerini tespit eder ve `/tmp/dns-resolved.json` dosyasına kaydeder. Yetki varsa bunları `/etc/hosts` dosyasına da ekler.
2. **Node.js Desteği (`scripts/dns-fix.cjs`):**
   - Playwright, WhatsApp köprüsü (whatsapp-bridge) veya arayüz derleme işlemleri gibi Node.js süreçleri için `NODE_OPTIONS` çevre değişkeni ile `--require scripts/dns-fix.cjs` yüklenir. Bu sayede tüm Node.js süreçleri engelli alan adlarını otomatik olarak çözümler.
3. **Python Desteği (`scripts/sitecustomize.py`):**
   - Hermes Agent'ın kendisi ve diğer Python süreçleri için `PYTHONPATH` değişkenine `scripts` dizini eklenerek `sitecustomize.py` dosyasının otomatik yüklenmesi sağlanır.
   - Bu dosya, `socket.getaddrinfo` fonksiyonunu monkeypatching yöntemiyle yamalar.
   - **Thread-local Reentrancy Koruması:** Yama, DoH HTTP istekleri yaparken oluşabilecek sonsuz döngüleri (recursion) engellemek amacıyla thread-local değişkenler kullanır ve güvenli bir çözümleme sağlar.

---

## 💾 GitHub ile Otomatik Yedekleme ve Geri Yükleme (Backup & Restore)

Uygulamanın oturum geçmişi, veritabanı ve ayarları (`.hermes` dizini ve `config.yaml` dosyası) Hugging Face Spaces gibi geçici (ephemeral) ortamlarda konteyner sıfırlandığında kaybolabilir. Bunu önlemek için **GitHub tabanlı dinamik yedekleme ve geri yükleme** mekanizması (`scripts/github-backup.sh`) eklenmiştir.

### ⚙️ Çalışma Mantığı ve Gelişmiş Güvenlik:
1. **Geri Yükleme (Restore - Başlangıçta):**
   - Konteyner başlatılırken `GITHUB_BACKUP_REPO` tanımlı ise, ilgili depo otomatik olarak geçici bir dizine klonlanır.
   - Depo içerisindeki `.hermes/` dizini ve `config.yaml` dosyası, uygulamanın çalışacağı ana dizine kopyalanarak verileriniz kaldığı yerden geri yüklenir.
   - **Güvenli Geri Yükleme (Safe Legacy Tar Extract):** Geri yükleme sırasında eski tar.gz formatındaki (`hermes_backup.tar.gz`) yedekler de desteklenir. Aktif çalışma ortamındaki kritik dosyaların (özellikle `/home/user/app/scripts/` altındaki özel ağ yamalarının ve scriptlerin) üzerine yanlışlıkla yazılmasını (overwriting) önlemek için; tar.gz arşivi önce güvenli geçici bir dizine açılır, ardından yalnızca `.hermes` veri klasörü ile `config.yaml` ayar dosyası hedef dizinlerine seçici olarak kopyalanır.

2. **Periyodik Yedekleme (Backup - Çalışma Esnasında):**
   - Arka planda çalışan bir servis, her **2 saatte bir** (varsayılan olarak) en güncel `.hermes` verilerini ve `config.yaml` dosyasını kontrol eder.
   - Herhangi bir değişiklik algılanırsa, değişiklikler otomatik olarak commit edilip GitHub deponuza güvenli bir şekilde gönderilir (push edilir).

3. **Kapatma Esnasında Yedekleme (Graceful Shutdown):**
   - Hugging Face Spaces konteyneri durdurulduğunda (uyku moduna geçiş, yeniden başlatma vb.), sistem `SIGTERM` veya `SIGINT` sinyalini yakalar ve kapanmadan önce **en güncel durumu son bir kez GitHub deponuza push eder**.

4. **Kalıcı Loglama ve Geçmiş Takibi:**
   - Yedekleme ve geri yükleme işlemleri kullanıcı tarafından kolayca takip edilebilir. Tüm adımlar, zaman damgalı durum logları (`INFO`, `SUCCESS`, `WARNING`, `ERROR`) olarak standart çıktıya (stdout) basılır ve kalıcı olarak `$HOME/app/backup.log` dosyasına kaydedilir.
   - Yedekleme geçmişinin kaybolmaması için `backup.log` dosyası, yedekleme ve geri yükleme adımlarında çalışma dizini ile GitHub deposu arasında karşılıklı olarak kopyalanarak korunur.

### 🛠️ Kurulum Adımları:
1. **Yedekleme Deposu Oluşturun:**
   - GitHub üzerinde özel (private) veya genel (public) yeni bir depo (repository) oluşturun (örn: `hermes-yedek`).
2. **Kişisel Erişim Token'ı (PAT) Alın:**
   - GitHub profilinizden **Settings** -> **Developer Settings** -> **Personal Access Tokens** -> **Tokens (classic)** yolunu izleyin.
   - **`repo`** (depo okuma/yazma) iznini seçerek bir token üretin ve kopyalayın.
3. **Hugging Face Spaces Üzerinde Yapılandırın:**
   - Hugging Face Space sayfanızda **Settings** -> **Variables and Secrets** alanına gidin.
   - **`GITHUB_BACKUP_REPO`** adında bir Secret veya Variable ekleyin ve değerini `github.com/kullanici/depo-adi` formatında girin.
   - **`GITHUB_TOKEN`** adında bir Secret ekleyin ve kopyaladığınız GitHub erişim token'ını yapıştırın.

> 🔒 **Güvenlik Bilgisi:** Başlangıç loglarında veya push işlemlerinde herhangi bir hata oluşması durumunda, güvenlik amacıyla `GITHUB_TOKEN` değeriniz otomatik olarak maskelenir (`[MASKED_TOKEN]`) ve loglarda açık bir şekilde görünmesi engellenir.

> 📦 **Büyük Dosya ve Limit Koruması:** GitHub dosya boyutu limitlerini (örn: 50MB/100MB limitleri) aşmamak için, sistem büyük boyutlu çalışma ortamı binary dosyalarını ve ortam bağımlılıklarını (`.hermes/bin`, `.hermes/node`, `.hermes/hermes-agent`, `.hermes/venv`, `.hermes/node_modules`) yedeklemeden otomatik olarak hariç tutar. Bu sayede sadece veri tabanınız, geçmiş oturumlarınız ve ayarlarınız hızlı ve sorunsuz şekilde yedeklenir.

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

### 2. Sistem ve Altyapı Değişkenleri

| Değişken Adı | Türü | Varsayılan | Açıklama |
| :--- | :--- | :--- | :--- |
| `PORT` | Değişken | `7860` | Ana kontrol panelinin dinleyeceği port. Hugging Face Spaces bunu otomatik ayarlar. |
| `HF_TOKEN` | Sır (Secret) | *(Boş)* | Hugging Face API erişim token'ı. Geri yükleme doğrulaması ve model API erişimleri için kullanılır. |

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
| `GITHUB_BACKUP_REPO` | Değişken/Sır | *(Boş)* | Yedeklerin saklanacağı GitHub deposunun adresi (örn. `github.com/kullanici/hermes-yedek` veya `https://github.com/kullanici/hermes-yedek.git`). |
| `GITHUB_TOKEN` | Sır (Secret) | *(Boş)* | GitHub deposuna yazma yetkisi olan kişisel erişim token'ı (Personal Access Token - PAT). Yedeklerin depoya push edilebilmesi için gereklidir. |

---

## 🗝️ API Anahtarları ve Detaylı Tanımlama Rehberi

Hermes Agent'ın yapay zeka modellerini çalıştırabilmesi, web taraması yapabilmesi ve otomatik yedekleme alabilmesi için çeşitli API anahtarlarına ihtiyacı vardır. Bu anahtarların her birinin görevi ve nasıl tanımlanacağı aşağıda detaylıca açıklanmıştır.

### 📋 Desteklenen API Anahtarları ve Görevleri

| API Anahtarı Değişkeni | Sağlayıcı / Servis | Açıklama ve Kullanım Amacı |
| :--- | :--- | :--- |
| `OPENROUTER_API_KEY` | **OpenRouter** | **En Kritik Anahtar!** Hermes Agent varsayılan olarak `nvidia/nemotron-3-ultra-550b-a55b:free` modelini OpenRouter üzerinden kullanır. Ayrıca yüzlerce açık kaynaklı ve ticari modele tek bir anahtar ile erişim sağlar. |
| `OPENAI_API_KEY` | **OpenAI** | `gpt-4o`, `gpt-4o-mini`, `o1`, `o3-mini` vb. resmi OpenAI modellerini doğrudan kullanmak için gereklidir. |
| `ANTHROPIC_API_KEY` | **Anthropic** | Sektör lideri `claude-3-5-sonnet`, `claude-3-opus` gibi Claude modellerini doğrudan Anthropic altyapısından çağırmak için kullanılır. |
| `DEEPSEEK_API_KEY` | **DeepSeek** | Akıl yürütme (reasoning) ve kodlama konusunda çok güçlü olan `deepseek-chat` (DeepSeek-V3) ve `deepseek-reasoner` (DeepSeek-R1) modellerini doğrudan resmi DeepSeek API'si üzerinden kullanmak için eklenmelidir. |
| `GROQ_API_KEY` | **Groq** | LLaMA 3, Mixtral gibi açık kaynaklı modelleri son derece yüksek hızlarda (token/saniye) çalıştırmak için eklenir. |
| `HF_TOKEN` | **Hugging Face** | Hem kodlarınızın GitHub'dan Hugging Face Spaces'e otomatik senkronizasyonu için, hem de Hugging Face üzerindeki açık kaynaklı modelleri barındıran API'leri sorgulamak için kullanılır. |
| `GITHUB_TOKEN` | **GitHub** | `.hermes` veri klasörü ile `config.yaml` dosyasındaki değişiklikleri belirlediğiniz özel/genel GitHub deponuza periyodik ve otomatik olarak yedeklemek (push/clone) için zorunludur. |

---

### 🛠️ API Anahtarları Hangi Ortamda Nasıl Tanımlanır?

Uygulamayı çalıştırdığınız platforma göre API anahtarlarını tanımlama yöntemleri aşağıda detaylandırılmıştır:

#### Yöntem A: Hugging Face Spaces Üzerinde Tanımlama (Önerilen)
Hugging Face Spaces üzerinde API anahtarlarınızı asla açık kaynak kodlara veya `config.yaml` içerisine düz metin (plain text) olarak yazmamalısınız. Bunlar her zaman **Secret (Gizli Değişken)** olarak tanımlanmalıdır.

1. **Hugging Face Space Sayfanıza Gidin:** Space arayüzünüzün üst barındaki **Settings** (Ayarlar) sekmesine tıklayın.
2. **Variables and Secrets Bölümüne Gidin:** Sayfayı aşağı kaydırarak **Variables and secrets** bölümünü bulun.
3. **Yeni Bir Gizli Değişken Ekleyin (New Secret):**
   - **"New Secret"** butonuna tıklayın.
   - **Name (Adı):** Tanımlayacağınız API anahtarının adını girin (Örn: `OPENROUTER_API_KEY`, `OPENAI_API_KEY` veya `GITHUB_TOKEN`).
   - **Value (Değeri):** API sağlayıcınızdan aldığınız gizli anahtarı yapıştırın.
   - **Save** butonuna basarak kaydedin.
4. **Yeniden Başlatma:** Bir Secret eklediğinizde veya güncellediğinizde, Hugging Face Space uygulamanızı bu yeni güvenli değişkenlerle **otomatik olarak yeniden başlatacaktır**.

*(Not: `GITHUB_BACKUP_REPO` gibi gizli olmayan ve sadece depo adresini tutan değişkenleri "New Variable" butonuna tıklayarak düz çevre değişkeni olarak da ekleyebilirsiniz.)*

---

#### Yöntem B: Yerel Docker Ortamında Tanımlama (Local Development)
Projeyi kendi bilgisayarınızda Docker ile çalıştırırken API anahtarlarını iki farklı şekilde tanımlayabilirsiniz:

##### 1. Docker `run` Komutu Esnasında Doğrudan (`-e` Parametresi ile):
Konteyneri başlatırken her bir anahtarı `-e` parametresiyle geçebilir, ayrıca `-v "$HOME/.hermes:/home/user/.hermes"` (Yerel Ev Dizini) veya `-v hermes-data:/home/user/.hermes` (Docker Hacmi) tercih edebilirsiniz:
```bash
docker run -d \
  -p 7860:7860 \
  -p 7861:7861 \
  -e HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin \
  -e HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=GucluBirSifre123! \
  -e OPENROUTER_API_KEY="sk-or-v1-xxxxxxxxxxxx..." \
  -e OPENAI_API_KEY="sk-proj-xxxxxxxxxxxx..." \
  -e GITHUB_BACKUP_REPO="github.com/kullanici/hermes-yedek" \
  -e GITHUB_TOKEN="ghp_xxxxxxxxxxxx..." \
  -v "$HOME/.hermes:/home/user/.hermes" \
  my-hermes-agent
```

##### 2. `.env` Dosyası Kullanarak (Daha Pratik):
Proje kök dizininde gizli bir `.env` dosyası oluşturun ve içerisine anahtarlarınızı yazın:
```env
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=GucluBirSifre123!
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxx...
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxx...
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxx...
GITHUB_BACKUP_REPO=github.com/kullanici/hermes-yedek
GITHUB_TOKEN=ghp_xxxxxxxxxxxx...
```
Ardından Docker konteynerini bu `.env` dosyasını referans göstererek tek seferde başlatın (Yerel Ev Dizini `-v "$HOME/.hermes:/home/user/.hermes"` veya Docker Hacmi `-v hermes-data:/home/user/.hermes` kullanabilirsiniz):
```bash
# Seçenek A: Yerel Ev Dizini
docker run -d -p 7860:7860 -p 7861:7861 -v "$HOME/.hermes:/home/user/.hermes" --env-file .env my-hermes-agent

# Seçenek B: Docker Hacmi
docker run -d -p 7860:7860 -p 7861:7861 -v hermes-data:/home/user/.hermes --env-file .env my-hermes-agent
```

#### 📦 Docker'da `.env` İçe Aktarımı ve Detaylı Çalışma Prensibi

##### Docker'da `.env` Dosyasının Rolü ve Güvenlik Uyarıları:
- **Derleme (Build Time) Güvenliği:** Docker imajını derlerken (`docker build`), proje dizinindeki `.env` dosyası imaja **kopyalanmaz** veya dahil edilmez. Bu, API anahtarlarınızın ve şifrelerinizin Docker imajının katmanlarında kalıcı olarak saklanmasını engellediği için son derece kritik bir güvenlik önlemidir.
- **Çalışma Zamanı (Runtime) Entegrasyonu:** `.env` dosyasının içeriği, konteyneri çalıştırırken (`docker run`) `--env-file .env` parametresiyle dinamik olarak Docker sürecine enjekte edilir. Bu sayede tüm gizli anahtarlar sadece çalışma zamanında RAM üzerinde tutulur.

##### Otomatik .env Senkronizasyonu ve Çözüm Mantığı:
Kullanıcıların setup-wizard.sh ile oluşturdukları `.env` dosyasındaki API anahtarlarının (örneğin `OPENROUTER_API_KEY`) web arayüzünde görünmemesi veya algılanmaması sorunu, Hermes Agent'ın gizli anahtarları ayrı bir konumda (`~/.hermes/.env` ve `~/.config/hermes/.env`) araması ve `config.yaml` ile birlikte ayrı dosyalar halinde yönetmesinden kaynaklanmaktadır.

Geliştirdiğimiz entegre çözüm sayesinde:
1. Konteyner ayağa kalkarken `scripts/start.sh` dosyası, çalışma dizinindeki (`$HOME/app/.env`) yerel `.env` dosyasını otomatik olarak tespit eder ve `source` ederek çevre değişkenlerini kabuğa aktarır.
2. start.sh içindeki Python entegrasyon betiği, kabuktaki tüm kritik anahtarları (API_KEY, TOKEN ve HERMES_ ile başlayan değişkenleri) toplayıp, Hermes Agent'ın kendi çalışma dizinlerindeki (`~/.hermes/.env` ve `~/.config/hermes/.env`) `.env` dosyalarına dinamik olarak yazar ve senkronize tutar.
3. Böylece hem `config.yaml` hem de `.env` dosyaları birbiriyle tam uyumlu çalışarak OpenRouter veya diğer AI API anahtarlarının Hermes Dashboard arayüzünde eksiksiz ve anında algılanmasını sağlar.

##### Çalıştırma Örneği (Docker CLI):
```bash
# Adım 1: Sihirbazı çalıştırıp yerel .env dosyasını oluşturun
./scripts/setup-wizard.sh

# Adım 2: Docker imajını güvenle derleyin (gizli anahtarlar imaja gömülmez)
docker build -t my-hermes-agent .

# Adım 3: .env dosyasını --env-file ile referans göstererek konteyneri çalıştırın (tercih ettiğiniz veri saklama yöntemi ile)
# Seçenek A: Yerel Ev Dizini
docker run -d --name hermes -p 7860:7860 -p 7861:7861 -v "$HOME/.hermes:/home/user/.hermes" --env-file .env my-hermes-agent

# Seçenek B: Docker Hacmi
# docker run -d --name hermes -p 7860:7860 -p 7861:7861 -v hermes-data:/home/user/.hermes --env-file .env my-hermes-agent
```

---

#### Yöntem C: GitHub Actions Üzerinde Tanımlama (Otomatik Senkronizasyon İçin)
Kodlarınızı GitHub'a yüklediğinizde Hugging Face Space'inizin otomatik olarak güncellenmesi için (`.github/workflows/hf-sync.yml` tetiklendiğinde) Hugging Face Write Token'ınızı GitHub Sırları (Secrets) arasına eklemelisiniz:

1. **Hugging Face Token'ı Alın:**
   - [Hugging Face Settings -> Tokens](https://huggingface.co/settings/tokens) adresine gidin.
   - **New Token** butonuna tıklayın.
   - Rolünü mutlaka **Write** (Yazma) yapın ve oluşturulan token'ı kopyalayın.
2. **GitHub Deponuza Ekleyin:**
   - GitHub üzerinde kodlarınızın bulunduğu deponun **Settings** sekmesine girin.
   - Sol menüden **Secrets and variables** -> **Actions** yolunu takip edin.
   - **"New repository secret"** butonuna tıklayın.
   - **Name:** `HF_TOKEN` yazın.
   - **Value:** Kopyaladığınız Hugging Face Write token'ını yapıştırın.
   - **Add secret** butonuna tıklayarak tamamlayın.

---

## 🔄 GitHub ve Hugging Face Spaces Senkronizasyonu

GitHub deponuza kod yüklediğinizde, bu kodların otomatik olarak Hugging Face Space'inize senkronize edilmesi için `.github/workflows/hf-sync.yml` iş akışı (workflow) dosyası kullanılmaktadır.

### Adım Adım Otomatik Senkronizasyon Kurulumu:
1. **Hugging Face Token Alın:**
   - [Hugging Face Access Tokens](https://huggingface.co/settings/tokens) sayfasına gidin.
   - **New Token** butonuna tıklayıp rolü **Write** (Yazma yetkisi) olarak seçin, kopyalayın.
2. **GitHub Deponuza Token'ı Ekleyin:**
   - GitHub deponuzun **Settings** -> **Secrets and variables** -> **Actions** menüsüne gidin.
   - **New repository secret** butonuna tıklayın.
   - Adını tam olarak `HF_TOKEN` yapın ve kopyaladığınız token'ı yapıştırın.
   - **Add secret** butonuna tıklayarak kaydedin.

Artık GitHub deponuzun `main` dalına (branch) her `git push` yaptığınızda, GitHub Actions otomatik olarak çalışacak ve en güncel kodlarınızı Hugging Face Space'inize yükleyecektir.
