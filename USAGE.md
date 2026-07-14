# MyHermes Projesi - Detaylı Kullanım Kılavuzu (USAGE.md)

Bu kılavuz, **Hermes Agent** web arayüzünün (Dashboard) Hugging Face Spaces veya yerel bir Docker ortamında nasıl kurulacağını, çalıştırılacağını, gelişmiş ağ (DNS) çözümlerini ve güvenlik yapılandırmalarını detaylandırmaktadır.

---

## 🚀 Başlangıç ve Çalıştırma

Bu proje, Hermes Agent Dashboard'u bir Docker konteyneri içinde barındırır. Hugging Face Spaces üzerinde sorunsuz ve yüksek performanslı çalışacak şekilde optimize edilmiştir.

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

---

## 🔒 Güvenlik ve Dinamik Kimlik Doğrulama (Authentication)

Dış dünyaya açık (kamusal IP'ye veya `0.0.0.0` adresine bağlanan) tüm Hermes Dashboard arayüzlerinde kimlik doğrulama yapılması zorunludur.

> ⚠️ **Önemli Bilgi:** `--insecure` parametresi artık pasiftir (deprecated / no-op) ve dışarıya açık bağlantılarda kimlik doğrulamayı devre dışı bırakmaz. Kamusal bağlantılarda her zaman geçerli bir kimlik doğrulama sağlayıcısı bulunmalıdır.

### 🛠️ Dinamik Kimlik Doğrulama Nasıl Çalışır?
Konteyner her başlatıldığında `scripts/start.sh` dosyası devreye girerek kimlik doğrulamayı şu adımlarla dinamik olarak yapılandırır:

1. **Şifre Algılama ve Hash'leme:**
   - Eğer `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` çevre değişkeni tanımlanmışsa, bu şifre Hermes Agent'ın yerleşik `plugins.dashboard_auth.basic.hash_password` aracı kullanılarak güvenli bir şekilde `scrypt` algoritması ile hash'lenir ve `config.yaml` dosyasındaki `password_hash` alanına yazılır.
   - Eğer doğrudan `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH` tanımlanmışsa, bu değer doğrudan kullanılır.
   - Eğer hiçbir şifre veya hash tanımlanmamışsa, sistem **otomatik olarak 12 karakterli güvenli bir şifre üretir**, bunu hash'ler ve başlangıç loglarında net bir şekilde görüntüler.
2. **Eklenti Aktivasyonu:**
   - Kimlik doğrulama hatalarını önlemek için `config.yaml` içindeki `plugins.disabled` listesinde `basic` eklentisi varsa kaldırılır, `plugins.enabled` listesine ise otomatik olarak eklenir.

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

## 🔑 Çevre Değişkenleri (Environment Variables) ve Sırlar (Secrets)

Uygulamanın çalışması için aşağıdaki değişkenler kullanılmaktadır. Bunları Hugging Face Spaces ayarlarında **Variables** veya **Secrets** olarak tanımlayabilirsiniz.

### 1. Kimlik Doğrulama Değişkenleri

| Değişken Adı | Türü | Varsayılan | Açıklama |
| :--- | :--- | :--- | :--- |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | Değişken/Sır | `admin` | Dashboard arayüzüne giriş kullanıcı adı. |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | Sır (Secret) | *(Otomatik Üretilir)* | Giriş şifresi. Belirtilmezse, başlangıçta rastgele üretilir ve loglara basılır. |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH` | Sır (Secret) | *(Boş)* | Şifrenin düz metin olarak girilmesini istemiyorsanız, önceden üretilmiş `scrypt` hash değerini buraya tanımlayabilirsiniz. |

### 2. Sistem ve Altyapı Değişkenleri

| Değişken Adı | Türü | Varsayılan | Açıklama |
| :--- | :--- | :--- | :--- |
| `PORT` | Değişken | `7860` | Uygulamanın dinleyeceği port. Hugging Face Spaces bunu otomatik ayarlar. |
| `HF_TOKEN` | Sır (Secret) | *(Boş)* | Hugging Face API erişim token'ı. Geri yükleme (`tar.gz`) doğrulaması ve model API erişimleri için kullanılır. |

### 3. Yapay Zeka (AI) API Anahtarları
Kullanmak istediğiniz modellere göre ilgili sağlayıcıların API anahtarlarını **Secret** olarak ekleyin:
- **OpenAI:** `OPENAI_API_KEY`
- **Anthropic:** `ANTHROPIC_API_KEY`
- **OpenRouter:** `OPENROUTER_API_KEY`
- **DeepSeek:** `DEEPSEEK_API_KEY`
- **Groq:** `GROQ_API_KEY`

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
