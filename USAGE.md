# Hermes Agent Kullanım Kılavuzu (USAGE.md)

Bu dosya, MyHermes projesinin Hugging Face Spaces veya yerel Docker ortamında nasıl kurulacağını, çalıştırılacağını, gerekli çevre değişkenlerini (Environment Variables) ve sırları (Secrets) açıklamaktadır.

---

## 🚀 Başlangıç ve Çalıştırma

Bu proje, **Hermes Agent** web arayüzünü (Dashboard) bir Docker konteyneri içinde barındırır. Hugging Face Spaces üzerinde doğrudan çalışacak şekilde tasarlanmıştır.

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

## 🔑 Çevre Değişkenleri (Environment Variables) ve Sırlar (Secrets)

Uygulamanın düzgün çalışması ve güvenliği için aşağıdaki değişkenler kullanılmaktadır. Bunları Hugging Face Spaces ayarlarında **Variables** veya **Secrets** olarak tanımlayabilirsiniz.

### 1. Kimlik Doğrulama Değişkenleri (Dashboard Güvenliği)

| Değişken Adı | Türü | Varsayılan | Açıklama |
| :--- | :--- | :--- | :--- |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | Değişken/Sır | `admin` | Dashboard arayüzüne giriş yaparken kullanılacak kullanıcı adı. |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | Sır (Secret) | *(Otomatik Üretilir)* | Giriş şifresi. Belirtilmezse, başlangıçta güvenli bir şifre rastgele üretilir ve loglara basılır. |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH` | Sır (Secret) | *(Boş)* | Şifrenin doğrudan düz metin olarak girilmesini istemiyorsanız, önceden üretilmiş `scrypt` hash değerini buraya tanımlayabilirsiniz. |

> 💡 **Önemli Not:** Eğer `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` veya `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH` belirtilmezse, sistem otomatik olarak 12 karakterli güvenli bir şifre üretir ve bunu konteyner başlangıç loglarında gösterir.

### 2. Sistem ve Altyapı Değişkenleri

| Değişken Adı | Türü | Varsayılan | Açıklama |
| :--- | :--- | :--- | :--- |
| `PORT` | Değişken | `7860` | Uygulamanın dinleyeceği port. Hugging Face Spaces otomatik olarak portu atayacaktır. |
| `HF_TOKEN` | Sır (Secret) | *(Boş)* | Hugging Face API erişim token'ı. Eğer yedekleme verileriniz varsa, geri yükleme (`tar.gz`) aşamasında doğrulamak için kullanılır. |

### 3. Yapay Zeka (AI) Sağlayıcı Değişkenleri (Model API Keys)
Hermes Agent'ın çalışabilmesi için yapılandırdığınız modele bağlı olarak ilgili API anahtarlarını da **Secret** olarak eklemeniz gerekir:

- **Hugging Face Serverless/Dedicated:** `HF_TOKEN`
- **OpenAI:** `OPENAI_API_KEY`
- **Anthropic (Claude):** `ANTHROPIC_API_KEY`
- **OpenRouter:** `OPENROUTER_API_KEY`
- **DeepSeek:** `DEEPSEEK_API_KEY`
- **Groq:** `GROQ_API_KEY`

---

## 🛠️ Nasıl Çalışır? (Teknik Detaylar)

1. **`Dockerfile`**: Gerekli sistem paketlerini yükler, `user` adında yetkisiz bir kullanıcı oluşturur, Hermes Agent CLI aracını kurar ve bağımlılıkları yükler.
2. **`scripts/start.sh`**:
   - `HF_TOKEN` ve ilgili yedek dosyası varsa yedeği geri yükler.
   - Belirttiğiniz kullanıcı adı ve şifreye göre `config.yaml` dosyasını dinamik olarak günceller ve güvenli şifre hash'leme işlemini gerçekleştirir.
   - Konfigürasyon dosyasını Hermes'in aradığı varsayılan konumlara (`~/.config/hermes/` ve `~/.hermes/`) kopyalar.
   - Dashboard'u `0.0.0.0` IP'sine bağlayarak dış erişime açar ve konteyneri ayakta tutar.

---

## ⚠️ Dikkat Edilmesi Gerekenler

- **Güvenlik:** Dashboard'u dış dünyaya açık (`0.0.0.0` bind) olarak çalıştırırken **kesinlikle** güçlü bir şifre (`HERMES_DASHBOARD_BASIC_AUTH_PASSWORD`) belirleyin. Aksi takdirde, otomatik üretilen şifreyi loglardan takip etmeniz gerekir.
- **Kalıcılık (Persistence):** Hugging Face Spaces geçici bir dosya sistemi kullandığından, oluşturulan veya indirilen dosyalar Space yeniden başladığında silinir. Kalıcılık gerektiren işlemler için yedekleme veya harici veri tabanı entegrasyonu önerilir.

---

## 🔄 GitHub ve Hugging Face Spaces Senkronizasyonu

### 1. Kodların Aynı Olup Olmadığını Kontrol Etme
Hugging Face üzerindeki Space'iniz **özel (private)** olduğu için, dışarıdan veya yetkisiz araçlarla doğrudan kodların birebir karşılaştırılması mümkün değildir. Ancak kendi bilgisayarınızda şu adımlarla karşılaştırma yapabilirsiniz:
1. Hugging Face Space'inizi bilgisayarınıza klonlayın (Hugging Face kullanıcı adınız ve write/read token'ınız ile):
   ```bash
   git clone https://huggingface.co/spaces/ertugrulerata/myHermes hf_deposu
   ```
2. GitHub deponuzdaki dosyalar ile bu klasörü karşılaştırın.
3. *Alternatif olarak, aşağıdaki otomatik senkronizasyonu kurduğunuzda, her push işleminde GitHub'daki kodlarınız otomatik olarak Hugging Face'e yüklenecek ve kodlarınız her zaman birebir aynı olacaktır!*

### 2. GitHub'dan Hugging Face'e Otomatik Yükleme (GitHub Actions)
GitHub deponuza kod yüklediğinizde, bu kodların otomatik olarak Hugging Face Space'inize senkronize edilmesi için `.github/workflows/hf-sync.yml` iş akışı (workflow) dosyası oluşturulmuştur.

Bu sistemin çalışması için GitHub deponuza Hugging Face erişim token'ınızı (Secret) tanımlamanız gerekir.

#### Adım Adım Kurulum:
1. **Hugging Face Token Alın:**
   - [Hugging Face Access Tokens](https://huggingface.co/settings/tokens) sayfasına gidin.
   - **New Token** butonuna tıklayın.
   - Token rolünü **Write** (Yazma yetkisi) olarak seçin, bir isim verin ve oluşturulan token'ı kopyalayın.

2. **GitHub Deponuza Token'ı Ekleyin:**
   - GitHub'daki deponuzun sayfasına gidin (tarayıcıdan).
   - Üst menüden **Settings (Ayarlar)** sekmesine tıklayın.
   - Sol menüden **Secrets and variables** -> **Actions** seçeneğine tıklayın.
   - **New repository secret** butonuna tıklayın.
   - **Name** alanına tam olarak şu adı yazın: `HF_TOKEN`
   - **Secret** alanına az önce kopyaladığınız Hugging Face Token'ınızı yapıştırın.
   - **Add secret** butonuna tıklayarak kaydedin.

Artık GitHub deponuzun `main` dalına (branch) her `git push` yaptığınızda, GitHub Actions otomatik olarak devreye girecek ve en güncel kodlarınızı Hugging Face Space'inize yükleyecektir. İşlemin durumunu GitHub deponuzdaki **Actions** sekmesinden takip edebilirsiniz.
