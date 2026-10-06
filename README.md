# MyHermes Agent

Hermes Agent dashboard, skills and automation environment ready for local or server Docker deployment.

## 🚀 Quick Start

1. **Clone repository and submodules:**
   ```bash
   git clone --recursive <repository-url>
   cd myHermes
   ```

2. **Run setup wizard or create `.env`:**
   ```bash
   ./hermes-start wizard
   ```

3. **Start with Docker Compose:**
   ```bash
   ./hermes-start
   ```
   Or manually:
   ```bash
   docker compose up -d --build
   ```

4. **Access Dashboard:**
   Open `http://localhost:7860` (or `http://<server-ip>:7860`) in your browser.

## 📚 Open Notebook MCP Bilgi Tabanı Entegrasyonu

`pdf-summarizer` becerisi, döküman özetlerini ve içeriklerini birincil bilgi tabanı olarak [Open Notebook](https://github.com/lfnovo/open-notebook) platformuna **Model Context Protocol (MCP)** ve REST API vasıtasıyla aktarır ve yönetir. Open Notebook ayrı bir IP/ağ üzerinde çalışabilir.

### 🌐 Ayrı IP / Uzak Sunucu Kurulum Kontrol Listesi:

Open Notebook servisini ayrı bir IP adresinde veya uzak sunucuda çalıştırırken aşağıdaki yapılandırmalara dikkat edilmelidir:

1. **CORS & Bind Address:** Open Notebook uygulamasının `127.0.0.1` yerine `0.0.0.0` IP adresi üzerinde dinleme yaptığından emin olun. Aksi halde dış ağlardan gelen bağlantılar reddedilir.
2. **Kimlik Doğrulama (Auth Token / API Key):** Servis ağa/internete açık olacağından `OPEN_NOTEBOOK_PASSWORD` (veya Bearer Token) kullanımı zorunlu hale getirilmelidir.
3. **Güvenlik Duvarı (Firewall / Port):** Open Notebook portunun (varsayılan: `5055`) Hermes sunucusunun IP adresinden gelen isteklere açık olduğunu doğrulayın:
   ```bash
   sudo ufw allow from <HERMES_IP> to any port 5055
   ```
4. **SSL/TLS & VPN (Güvenli İletişim):** Farklı bir lokasyon veya kamuya açık VPS ortamlarında bağlantı `https://` üzerinden kurulmalı veya Tailscale / WireGuard gibi güvenli bir VPN ağı kullanılmalıdır.

### ⚙️ MCP Sunucu Yapılandırması (`config.yaml`):

Open Notebook MCP bağlantısı `config.yaml` içerisinde `mcp_servers` altında yapılandırılır:

```yaml
mcp_servers:
  open-notebook:
    command: "open-notebook-mcp"
    args: []
    env:
      OPEN_NOTEBOOK_URL: "http://192.168.1.100:5055"
      OPEN_NOTEBOOK_PASSWORD: "${OPEN_NOTEBOOK_PASSWORD}"
```

### ⚙️ MCP Çevre Değişkenleri (`.env`):
Ayrı bir IP/port üzerinde çalışan Open Notebook sunucusuna bağlanmak için aşağıdaki çevre değişkenlerini ekleyebilirsiniz:

```env
# Open Notebook API Sunucu Adresi
OPEN_NOTEBOOK_URL=http://192.168.1.100:5055

# Kimlik Doğrulama Şifresi (Eğer şifre koruması aktifse)
OPEN_NOTEBOOK_PASSWORD=your_password_here

# Varsayılan Defter Adı
PDF_SUMMARIZER_OPEN_NOTEBOOK_NOTEBOOK=Bilgi Tabani

# Buzz Webhook Bildirim Adresi (İsteğe bağlı)
BUZZ_WEBHOOK_URL=https://relay.buzz.community/webhook/...
```

### 🛠️ Depolama Yardımcısı CLI Komutları:

```bash
# Defterleri listeleme:
python3 skills/pdf-summarizer/storage_helper.py --action list_notebooks

# Yeni defter oluşturma:
python3 skills/pdf-summarizer/storage_helper.py --action create_notebook --title "Araştırma Makaleleri"

# Uygun deftere dosya (PDF/Doc) ekleme (vektör dizinleme ve isteğe bağlı Buzz bildirimi ile):
python3 skills/pdf-summarizer/storage_helper.py --action add_source --notebook-id <NOTEBOOK_ID> --file-path /path/to/document.pdf --notify-buzz

# Uygun deftere web URL kaynağı ekleme (vektör dizinleme ve isteğe bağlı Buzz bildirimi ile):
python3 skills/pdf-summarizer/storage_helper.py --action add_source --notebook-id <NOTEBOOK_ID> --url "https://example.com/article" --notify-buzz

# Kaynağa özet çıkarttırma (dönüşüm ID tespiti ve tamamlama sorgulaması ile):
python3 skills/pdf-summarizer/storage_helper.py --action summarize --source-id <SOURCE_ID> --notify-buzz

# Çıkartılan özeti / kaynak detaylarını alma:
python3 skills/pdf-summarizer/storage_helper.py --action get_summary --source-id <SOURCE_ID>
```

For detailed documentation, configuration options, backup options, and skill details, see [USAGE.md](USAGE.md).
