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

For detailed documentation, configuration options, backup options, and skill details, see [USAGE.md](USAGE.md).
