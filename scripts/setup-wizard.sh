#!/bin/bash
# MyHermes Projesi - İnteraktif Kurulum Sihirbazı (setup-wizard.sh)
# Bu betik, kullanıcının Hermes Agent için gerekli tüm ayarları manuel ve kolayca yapabilmesini sağlar.

set -e

# Renk tanımlamaları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0;m' # No Color
BOLD='\033[1m'

# Proje kök dizinini bul
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

clear
echo -e "${PURPLE}${BOLD}"
echo "========================================================="
echo "   ☤  MYHERMES AGENT - İNTERAKTİF KURULUM SİHİRBAZI  ☤   "
echo "========================================================="
echo -e "${NC}"
echo -e "Bu sihirbaz, Hermes Agent'ın düzgün çalışması için gereken temel ayarları"
echo -e "manuel olarak seçmenize ve bir ${CYAN}.env${NC} dosyası oluşturmanıza yardımcı olacaktır."
echo

# -----------------------------------------------------------------------------
# STEP 1: Dashboard Kimlik Doğrulama Bilgileri
# -----------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Adım 1/5] Dashboard Giriş Bilgileri (Basic Auth)${NC}"
echo "Dış dünyaya veya ağa açık dashboard arayüzüne giriş için kimlik bilgileri gereklidir."

read -rp "Yönetici Kullanıcı Adı [Varsayılan: admin]: " db_username
db_username=${db_username:-admin}

read -rsp "Yönetici Giriş Şifresi (Girmek istemiyorsanız boş bırakın, otomatik üretilir): " db_password
echo
if [ -z "$db_password" ]; then
    # Güvenli rastgele şifre üretelim
    db_password=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12 || echo "HermesPass123!")
    echo -e "👉 Şifre boş bırakıldı. Sizin için üretilen güvenli şifre: ${YELLOW}${BOLD}$db_password${NC}"
else
    echo -e "👉 Şifre başarıyla kaydedildi."
fi
echo

# -----------------------------------------------------------------------------
# STEP 2: Yapay Zeka (AI) API Anahtarları
# -----------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Adım 2/5] Yapay Zeka (AI) API Anahtarları${NC}"
echo "Kullanmak istediğiniz servislerin API anahtarlarını giriniz. Boş bırakılanlar tanımlanmayacaktır."
echo

read -rp "OpenRouter API Key (En kritik anahtar, varsayılan modeller için önerilir): " key_openrouter
read -rp "OpenAI API Key (gpt-4o, gpt-4o-mini vb. için): " key_openai
read -rp "Anthropic API Key (claude-3-5-sonnet vb. için): " key_anthropic
read -rp "DeepSeek API Key (deepseek-chat, deepseek-reasoner için): " key_deepseek
read -rp "Groq API Key (Hızlı açık kaynaklı modeller için): " key_groq
echo

# -----------------------------------------------------------------------------
# STEP 3: GitHub Otomatik Yedekleme Ayarları
# -----------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Adım 3/5] GitHub Otomatik Yedekleme ve Geri Yükleme${NC}"
echo "Sohbet oturumlarınızın, verilerinizin ve ayarlarınızın kaybolmaması için"
echo "GitHub tabanlı bir yedekleme sistemi kurmanızı şiddetle tavsiye ederiz."
read -rp "GitHub yedekleme sistemini aktifleştirmek ister misiniz? (e/h) [Varsayılan: h]: " enable_backup
enable_backup=${enable_backup:-h}

backup_repo=""
backup_token=""
backup_interval="7200"

if [[ "$enable_backup" =~ ^[EeYy]$ ]]; then
    echo
    read -rp "GitHub Depo Adresi (Örn: github.com/kullanici/hermes-yedek): " backup_repo
    read -rsp "GitHub Personal Access Token (PAT) (Yazma/Okuma yetkili token): " backup_token
    echo
    read -rp "Yedekleme Sıklığı (Saat cinsinden) [Varsayılan: 2]: " backup_hours
    backup_hours=${backup_hours:-2}
    # Saniyeye çevirelim
    backup_interval=$((backup_hours * 3600))
    echo -e "👉 Yedekleme sıklığı: ${CYAN}$backup_hours saat${NC} ($backup_interval saniye) olarak ayarlandı."
else
    echo -e "👉 Yedekleme sistemi pasif bırakıldı."
fi
echo

# -----------------------------------------------------------------------------
# STEP 4: Open Notebook MCP Bilgi Tabanı Yapılandırması
# -----------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Adım 4/5] Open Notebook MCP Bilgi Tabanı Yapılandırması${NC}"
echo "PDF Summarizer ve bilgi yönetim becerilerinin döküman özetlerini"
echo "Open Notebook MCP sunucusuna aktarması için gerekli ayarlar."
echo -e "${YELLOW}Not: Ayrı IP/Sunucu kullanımında Open Notebook'un 0.0.0.0 adresini dinlediğinden,"
echo -e "OPEN_NOTEBOOK_PASSWORD tanımlandığından ve 5055 portunun ufw/firewall ile açık olduğundan emin olun.${NC}"
echo
read -rp "Open Notebook entegrasyonu aktifleştirilsin mi? (e/h) [Varsayılan: e]: " enable_open_notebook
enable_open_notebook=${enable_open_notebook:-e}

open_notebook_url="http://localhost:5055"
open_notebook_password=""
open_notebook_name="Bilgi Tabani"
open_notebook_enabled="true"

if [[ "$enable_open_notebook" =~ ^[EeYy]$ ]]; then
    open_notebook_enabled="true"
    read -rp "Open Notebook API URL [Varsayılan: http://localhost:5055]: " open_notebook_url
    open_notebook_url=${open_notebook_url:-http://localhost:5055}
    read -rsp "Open Notebook API Şifresi (Yoksa boş bırakın): " open_notebook_password
    echo
    if [ -z "$open_notebook_password" ]; then
        echo -e "${RED}⚠️  UYARI: Open Notebook şifresi boş bırakıldı. Şifresiz erişim yetkisiz işlemlere izin verebilir. Şifre kullanmanız şiddetle önerilir.${NC}"
    fi
    read -rp "Varsayılan Defter Adı Prefix'i [Varsayılan: Bilgi Tabani]: " open_notebook_name
    open_notebook_name=${open_notebook_name:-Bilgi Tabani}
    echo -e "👉 Open Notebook Entegrasyonu: ${GREEN}AKTİF${NC} (URL: ${CYAN}$open_notebook_url${NC})"
else
    open_notebook_enabled="false"
    echo -e "👉 Open Notebook entegrasyonu pasif bırakıldı."
fi
echo

# -----------------------------------------------------------------------------
# STEP 5: Genel Sistem Ayarları
# -----------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Adım 5/5] Genel Sistem Ayarları${NC}"
read -rp "Dinlenecek Port Numarası [Varsayılan: 7860]: " app_port
app_port=${app_port:-7860}
echo -e "👉 Uygulama Portu: ${CYAN}$app_port${NC}"
echo

# -----------------------------------------------------------------------------
# Yapılandırma Dosyasının (.env) Oluşturulması
# -----------------------------------------------------------------------------
echo -e "${YELLOW}${BOLD}Konfigürasyon yazılıyor...${NC}"

# .env dosyasını temizle veya oluştur
cat << EOF > "$ENV_FILE"
# MyHermes Konfigürasyon Dosyası
# Sihirbaz tarafından otomatik oluşturulmuştur. Tarih: $(date)

# 1. Kimlik Doğrulama Ayarları
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=$db_username
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=$db_password

# 2. Port Ayarı
PORT=$app_port

# 3. Yapay Zeka API Anahtarları
EOF

[ -n "$key_openrouter" ] && echo "OPENROUTER_API_KEY=$key_openrouter" >> "$ENV_FILE"
[ -n "$key_openai" ] && echo "OPENAI_API_KEY=$key_openai" >> "$ENV_FILE"
[ -n "$key_anthropic" ] && echo "ANTHROPIC_API_KEY=$key_anthropic" >> "$ENV_FILE"
[ -n "$key_deepseek" ] && echo "DEEPSEEK_API_KEY=$key_deepseek" >> "$ENV_FILE"
[ -n "$key_groq" ] && echo "GROQ_API_KEY=$key_groq" >> "$ENV_FILE"

cat << EOF >> "$ENV_FILE"

# 4. GitHub Yedekleme Ayarları
BACKUP_INTERVAL=$backup_interval
EOF

if [ -n "$backup_repo" ] && [ -n "$backup_token" ]; then
    echo "GITHUB_BACKUP_REPO=$backup_repo" >> "$ENV_FILE"
    echo "GITHUB_TOKEN=$backup_token" >> "$ENV_FILE"
fi

cat << EOF >> "$ENV_FILE"

# 5. Open Notebook MCP Bilgi Tabanı Ayarları
PDF_SUMMARIZER_OPEN_NOTEBOOK_ENABLED=$open_notebook_enabled
OPEN_NOTEBOOK_URL=$open_notebook_url
EOF

[ -n "$open_notebook_password" ] && echo "OPEN_NOTEBOOK_PASSWORD=$open_notebook_password" >> "$ENV_FILE"
echo "PDF_SUMMARIZER_OPEN_NOTEBOOK_NOTEBOOK=$open_notebook_name" >> "$ENV_FILE"

chmod 600 "$ENV_FILE"
echo -e "${GREEN}${BOLD}✔ Konfigürasyon başarıyla .env dosyasına kaydedildi!${NC}"
echo

# -----------------------------------------------------------------------------
# Çalıştırma Kılavuzu Gösterimi
# -----------------------------------------------------------------------------
echo -e "\n${GREEN}${BOLD}========================================================="
echo "   YEREL VEYA SUNUCU (DOCKER) - ÇALIŞTIRMA REHBERİ"
echo -e "=========================================================${NC}"
echo -e "Yerel makinenizde veya sunucunuzda çalıştırmak için aşağıdaki komutu kullanabilirsiniz:"
echo -e "  ${CYAN}docker compose up -d --build${NC} (Dashboard, GitHub yedekleme ve entegre Ofelia zamanlayıcısı dahil)"
echo
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo -e "Arayüz Erişim Adresleri:"
echo -e "  - Yerel (Local):   ${BLUE}${BOLD}http://localhost:$app_port${NC}"
if [ -n "$SERVER_IP" ] && [ "$SERVER_IP" != "127.0.0.1" ]; then
    echo -e "  - Sunucu (Server): ${BLUE}${BOLD}http://$SERVER_IP:$app_port${NC}"
else
    echo -e "  - Sunucu (Server): ${BLUE}${BOLD}http://<SUNUCU_IP>:$app_port${NC}"
fi
echo -e "Kullanıcı Adı: ${CYAN}$db_username${NC}"
echo -e "Şifre: ${CYAN}$db_password${NC}"
echo

read -rp "Docker Compose ile şimdi derleyip çalıştırmak ister misiniz? (e/h) [Varsayılan: e]: " auto_run
auto_run=${auto_run:-e}

if [[ "$auto_run" =~ ^[EeYy]$ ]]; then
    echo -e "\n${YELLOW}Git Submodule'ler güncelleniyor...${NC}"
    git submodule update --init --recursive 2>/dev/null || true
    echo -e "\n${YELLOW}Docker Compose ile servisler başlatılıyor...${NC}"
    if docker compose version &>/dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &>/dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD=""
    fi

    if [ -n "$COMPOSE_CMD" ]; then
        $COMPOSE_CMD up -d --build
        echo -e "${GREEN}${BOLD}✔ Hermes Agent (ve entegre Ofelia zamanlayıcısı) Docker Compose ile başarıyla başlatıldı!${NC}"
        echo -e "Arayüz Adresi (Yerel): ${BLUE}${BOLD}http://localhost:$app_port${NC}"
        if [ -n "$SERVER_IP" ] && [ "$SERVER_IP" != "127.0.0.1" ]; then
            echo -e "Arayüz Adresi (Sunucu): ${BLUE}${BOLD}http://$SERVER_IP:$app_port${NC}"
        fi
    else
        echo -e "${RED}❌ HATA: Sisteminizde 'docker-compose' veya 'docker compose' komutu bulunamadı!${NC}"
        echo -e "Lütfen Docker Compose'u yükleyin veya manuel olarak '${CYAN}docker compose up -d --build${NC}' komutunu çalıştırın."
    fi
fi

echo -e "\n${PURPLE}${BOLD}Kurulum Sihirbazı tamamlandı. Teşekkür ederiz!${NC}\n"
