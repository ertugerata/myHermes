# MyHermes Projesi - Detaylı Kullanım Kılavuzu (USAGE.md)

Bu kılavuz, **Hermes Agent** web arayüzünün (Dashboard) Hugging Face Spaces veya yerel bir Docker ortamında nasıl kurulacağını, çalıştırılacağını, gelişmiş ağ (DNS) çözümlerini, güvenlik yapılandırmalarını ve yedekleme mekanizmasını detaylandırmaktadır.

---

## 🚀 Başlangıç ve Çalıştırma

Bu proje, Hermes Agent Dashboard'u bir Docker konteyneri içinde barındırır. Hugging Face Spaces veya yerel konteyner ortamlarında sorunsuz, yüksek performanslı ve güvenli çalışacak şekilde optimize edilmiştir.

### Yerel Ortamda Docker ile Çalıştırma
Yerel makinenizde test etmek veya çalıştırmak için aşağıdaki adımları takip edebilirsiniz:

1. **Docker İmajını Derleyin:**
   ```bash
   docker build -t my-hermes-agent .
   ```

2. **Konteyneri Başlatın:**
   ```bash
   docker run -p 7860:7860 \
     -e HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin \
     -e HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=GucluBirSifre123! \
     my-hermes-agent
   ```
   Ardından tarayıcınızda `http://localhost:7860` adresine giderek giriş yapabilirsiniz.

### 🔄 Sinyal Yakalama ve Kesintisiz Çalışma (Graceful Shutdown)
Konteynerin Hugging Face Spaces veya Docker üzerinde beklenmedik şekilde aniden kapanmasını önlemek ve sistem sinyallerini düzgün yönetmek amacıyla, `hermes dashboard` komutu arka planda (`0.0.0.0` IP adresine bağlı olarak) çalıştırılır ve ön planda bir `wait` komutu ile beklenir.
Bu sayede shell üzerinde bir sinyal yakalayıcı (trap) kurulmuştur. Konteyner durdurulurken `SIGTERM` veya `SIGINT` sinyalleri yakalanarak son durum güvenli bir şekilde yedeklenir ve süreç kontrollü (graceful) olarak sonlandırılır.

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
   - Arka planda çalışan bir servis, her **30 dakikada bir** en güncel `.hermes` verilerini ve `config.yaml` dosyasını kontrol eder.
   - Herhangi bir değişiklik algılanırsa, değişiklikler otomatik olarak commit edilip GitHub deponuza güvenli bir şekilde gönderilir (push edilir).

3. **Kapatma Esnasında Yedekleme (Graceful Shutdown):**
   - Hugging Face Spaces konteyneri durdurulduğunda (uyku moduna geçiş, yeniden başlatma vb.), sistem `SIGTERM` veya `SIGINT` sinyalini yakalar ve kapanmadan önce **en güncel durumu son bir kez GitHub deposuna push eder**.

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
| `PORT` | Değişken | `7860` | Uygulamanın dinleyeceği port. Hugging Face Spaces bunu otomatik ayarlar. |
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
