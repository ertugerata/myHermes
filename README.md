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

`pdf-summarizer` becerisi, döküman özetlerini ve içeriklerini birincil bilgi tabanı olarak [Open Notebook](https://github.com/lfnovo/open-notebook) platformuna **Model Context Protocol (MCP)** vasıtasıyla aktarır ve yönetir. Open Notebook ayrı bir IP/ağ üzerinde çalışabilir.

### ⚙️ MCP Sunucu Yapılandırması (`config.yaml`):

Open Notebook MCP bağlantısı `config.yaml` içerisinde `mcpServers` altında yapılandırılır:

```yaml
mcpServers:
  open-notebook:
    command: "uvx"
    args:
      - "open-notebook-mcp"
    env:
      OPEN_NOTEBOOK_URL: "http://localhost:5055"
      OPEN_NOTEBOOK_PASSWORD: "your_open_notebook_password"
```

### ⚙️ MCP Çevre Değişkenleri (`.env`):
Ayrı bir IP/port üzerinde çalışan Open Notebook sunucusuna bağlanmak için aşağıdaki çevre değişkenlerini ekleyebilirsiniz:

```env
# Open Notebook API Sunucu Adresi
OPEN_NOTEBOOK_URL=http://192.168.1.100:5055

# Kimlik Doğrulama Şifresi (Eğer şifre koruması aktifse)
OPEN_NOTEBOOK_PASSWORD=your_password_here

# Buzz Webhook Bildirim Adresi (İsteğe bağlı)
BUZZ_WEBHOOK_URL=https://relay.buzz.community/webhook/...
```

### 🛠️ Depolama Yardımcısı CLI Komutları:

```bash
# Defterleri listeleme:
python3 skills/pdf-summarizer/storage_helper.py --action list_notebooks

# Yeni defter oluşturma:
python3 skills/pdf-summarizer/storage_helper.py --action create_notebook --title "Araştırma Makaleleri"

# Uygun deftere dosya (PDF/Doc) veya URL ekleme (isteğe bağlı Buzz bildirimi ile):
python3 skills/pdf-summarizer/storage_helper.py --action add_source --notebook-id <NOTEBOOK_ID> --file-path /path/to/document.pdf --notify-buzz

# Defterdeki dökümana özet çıkarttırma:
python3 skills/pdf-summarizer/storage_helper.py --action summarize --notebook-id <NOTEBOOK_ID> --source-id <SOURCE_ID> --notify-buzz

# Çıkartılan özeti / kaynak detaylarını alma:
python3 skills/pdf-summarizer/storage_helper.py --action get_summary --source-id <SOURCE_ID>
```

For detailed documentation, configuration options, backup options, and skill details, see [USAGE.md](USAGE.md).
