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

### ⚙️ MCP Bağlantı Ayarları (`.env`):
Ayrı bir IP adresinde bulunan Open Notebook sunucusuna bağlanmak için aşağıdaki çevre değişkenlerini ekleyin:

```env
# Open Notebook API Sunucu Adresi (Ayrı IP/Ağ üzerindeki sunucu)
OPEN_NOTEBOOK_URL=http://192.168.1.100:5055

# Kimlik Doğrulama Şifresi (Eğer Open Notebook üzerinde şifre koruması aktifse)
OPEN_NOTEBOOK_PASSWORD=your_password_here

# Hedef Defter Adı Prefix'i (Varsayılan: Bilgi Tabani)
PDF_SUMMARIZER_OPEN_NOTEBOOK_NOTEBOOK=Bilgi Tabani

# MCP Entegrasyonu Aktiflik Durumu (true/false)
PDF_SUMMARIZER_OPEN_NOTEBOOK_ENABLED=true
```

### 🛠️ Depolama Yardımcısı CLI Komutları:
```bash
# MCP Bağlantı durumunu kontrol etme:
python3 skills/pdf-summarizer/storage_helper.py open-notebook-status

# Özet raporu ve dökümanı Open Notebook Bilgi Tabanına senkronize etme:
python3 skills/pdf-summarizer/storage_helper.py sync-open-notebook "/tmp/Rapor_Ozet.md" "Yazilim" --doc-file "/tmp/Rapor.pdf"

# Kayıtlı notları/özetleri listeleme ve içerik çekme:
python3 skills/pdf-summarizer/storage_helper.py open-notebook-notes
python3 skills/pdf-summarizer/storage_helper.py open-notebook-get-note "<NOTE_ID>"

# Bilgi tabanında vektör araması ve soru sorma:
python3 skills/pdf-summarizer/storage_helper.py search-open-notebook "Yapay zeka modelleri"
python3 skills/pdf-summarizer/storage_helper.py ask-open-notebook "Raporlardaki ana bulgular nelerdir?"
```

For detailed documentation, configuration options, backup options, and skill details, see [USAGE.md](USAGE.md).
