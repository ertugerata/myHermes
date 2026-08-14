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
# STEP 1: Hedef Ortam Seçimi
# -----------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Adım 1/5] Hedef Dağıtım Ortamı Seçimi${NC}"
echo "Hermes Agent'ı nerede çalıştırmayı planlıyorsunuz?"
echo -e "  ${GREEN}1)${NC} Hugging Face Spaces"
echo -e "  ${GREEN}2)${NC} Yerel Docker Ortamı (Local Docker)"
read -rp "Seçiminiz (1-2) [Varsayılan: 2]: " target_env
target_env=${target_env:-2}

if [ "$target_env" = "1" ]; then
    TARGET_NAME="Hugging Face Spaces"
else
    TARGET_NAME="Yerel Docker"
fi
echo -e "👉 Seçilen Hedef Ortam: ${CYAN}${BOLD}$TARGET_NAME${NC}\n"

# -----------------------------------------------------------------------------
# STEP 2: Dashboard Kimlik Doğrulama Bilgileri
# -----------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Adım 2/5] Dashboard Giriş Bilgileri (Basic Auth)${NC}"
echo "Dış dünyaya açık dashboard arayüzüne giriş için kimlik bilgileri gereklidir."

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
# STEP 3: Yapay Zeka (AI) API Anahtarları
# -----------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Adım 3/5] Yapay Zeka (AI) API Anahtarları${NC}"
echo "Kullanmak istediğiniz servislerin API anahtarlarını giriniz. Boş bırakılanlar tanımlanmayacaktır."
echo

read -rp "OpenRouter API Key (En kritik anahtar, varsayılan modeller için önerilir): " key_openrouter
read -rp "OpenAI API Key (gpt-4o, gpt-4o-mini vb. için): " key_openai
read -rp "Anthropic API Key (claude-3-5-sonnet vb. için): " key_anthropic
read -rp "DeepSeek API Key (deepseek-chat, deepseek-reasoner için): " key_deepseek
read -rp "Groq API Key (Hızlı açık kaynaklı modeller için): " key_groq
echo

# -----------------------------------------------------------------------------
# STEP 4: GitHub Otomatik Yedekleme Ayarları
# -----------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Adım 4/5] GitHub Otomatik Yedekleme ve Geri Yükleme${NC}"
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

chmod 600 "$ENV_FILE"
echo -e "${GREEN}${BOLD}✔ Konfigürasyon başarıyla .env dosyasına kaydedildi!${NC}"
echo

# -----------------------------------------------------------------------------
# Dağıtım ve Çalıştırma Kılavuzu Gösterimi
# -----------------------------------------------------------------------------
if [ "$target_env" = "1" ]; then
    echo -e "${PURPLE}${BOLD}========================================================="
    echo "   HUGGING FACE SPACES - KURULUM REHBERİ"
    echo -e "=========================================================${NC}"
    echo -e "Hugging Face Spaces üzerinde güvenli çalıştırmak için lütfen"
    echo -e "Spaces ayarlarınızda (Settings -> Variables and secrets) şu alanları tanımlayın:"
    echo
    echo -e "🔐 ${BOLD}SECRETS (Gizli Sırlar):${NC}"
    echo -e "  - ${YELLOW}HERMES_DASHBOARD_BASIC_AUTH_PASSWORD${NC} = $db_password"
    [ -n "$key_openrouter" ] && echo -e "  - ${YELLOW}OPENROUTER_API_KEY${NC} = $key_openrouter"
    [ -n "$key_openai" ] && echo -e "  - ${YELLOW}OPENAI_API_KEY${NC} = $key_openai"
    [ -n "$key_anthropic" ] && echo -e "  - ${YELLOW}ANTHROPIC_API_KEY${NC} = $key_anthropic"
    [ -n "$key_deepseek" ] && echo -e "  - ${YELLOW}DEEPSEEK_API_KEY${NC} = $key_deepseek"
    [ -n "$key_groq" ] && echo -e "  - ${YELLOW}GROQ_API_KEY${NC} = $key_groq"
    [ -n "$backup_token" ] && echo -e "  - ${YELLOW}GITHUB_TOKEN${NC} = (Kopyaladığınız GitHub PAT)"
    echo
    echo -e "⚙️ ${BOLD}VARIABLES (Değişkenler):${NC}"
    echo -e "  - ${CYAN}HERMES_DASHBOARD_BASIC_AUTH_USERNAME${NC} = $db_username"
    echo -e "  - ${CYAN}PORT${NC} = $app_port"
    echo -e "  - ${CYAN}BACKUP_INTERVAL${NC} = $backup_interval"
    [ -n "$backup_repo" ] && echo -e "  - ${CYAN}GITHUB_BACKUP_REPO${NC} = $backup_repo"
    echo
    echo -e "💡 Bu sırları ve değişkenleri girdikten sonra Spaces uygulamanız otomatik"
    echo -e "yeniden derlenip güvenli bir şekilde başlayacaktır."
else
    echo -e "${BLUE}${BOLD}[Adım 5/5] Veri Saklama (Volume Mount) Tercihi${NC}"
    echo "Konteyner verilerinizin (sohbet geçmişi ve ayarlar) nerede saklanmasını istersiniz?"
    echo -e "  ${GREEN}1)${NC} Yerel Ev Dizini (Host üzerindeki ~/.hermes klasörünü bağlar - Önerilen)"
    echo -e "  ${GREEN}2)${NC} Docker Hacmi (hermes-data adında izole bir Docker Named Volume kullanır)"
    read -rp "Seçiminiz (1-2) [Varsayılan: 1]: " vol_choice
    vol_choice=${vol_choice:-1}

    if [ "$vol_choice" = "1" ]; then
        DOCKER_VOL_CMD="mkdir -p \"\$HOME/.hermes\" && docker run -d --name hermes -p $app_port:$app_port -v \"\$HOME/.hermes:/home/user/.hermes\" --env-file .env my-hermes-agent"
        DOCKER_VOL_RUN_PRE="mkdir -p \"\$HOME/.hermes\""
        DOCKER_VOL_RUN_CMD="docker run -d --name hermes -p \"$app_port:$app_port\" -v \"\$HOME/.hermes:/home/user/.hermes\" --env-file \"\$ENV_FILE\" my-hermes-agent"
    else
        DOCKER_VOL_CMD="docker run -d --name hermes -p $app_port:$app_port -v hermes-data:/home/user/.hermes --env-file .env my-hermes-agent"
        DOCKER_VOL_RUN_PRE="true"
        DOCKER_VOL_RUN_CMD="docker run -d --name hermes -p \"$app_port:$app_port\" -v hermes-data:/home/user/.hermes --env-file \"\$ENV_FILE\" my-hermes-agent"
    fi

    echo -e "\n${GREEN}${BOLD}========================================================="
    echo "   YEREL DOCKER - ÇALIŞTIRMA REHBERİ"
    echo -e "=========================================================${NC}"
    echo -e "Yerel Docker ortamında çalıştırmak için aşağıdaki komutu kullanabilirsiniz:"
    echo -e "  ${CYAN}docker build -t my-hermes-agent .${NC}"
    echo -e "  ${CYAN}$DOCKER_VOL_CMD${NC}"
    echo
    echo -e "Arayüze ${BOLD}http://localhost:$app_port${NC} adresinden ulaşabilirsiniz."
    echo -e "Kullanıcı Adı: ${CYAN}$db_username${NC}"
    echo -e "Şifre: ${CYAN}$db_password${NC}"
    echo

    read -rp "Docker imajını şimdi derlemek ve arka planda çalıştırmak ister misiniz? (e/h): " auto_run
    if [[ "$auto_run" =~ ^[EeYy]$ ]]; then
        echo -e "\n${YELLOW}Docker İmajı Derleniyor (Bu işlem birkaç dakika sürebilir)...${NC}"
        docker build -t my-hermes-agent .

        # Varsa eski konteyneri durdur ve sil
        if docker ps -a --format '{{.Names}}' | grep -Eq "^hermes$"; then
            echo -e "${YELLOW}Eski 'hermes' konteyneri durduruluyor ve kaldırılıyor...${NC}"
            docker rm -f hermes || true
        fi

        echo -e "${YELLOW}Konteyner Başlatılıyor...${NC}"
        eval "$DOCKER_VOL_RUN_PRE"
        eval "$DOCKER_VOL_RUN_CMD"
        echo -e "${GREEN}${BOLD}✔ Konteyner başarıyla arka planda başlatıldı!${NC}"
        echo -e "Arayüze erişmek için: ${BLUE}${BOLD}http://localhost:$app_port${NC}"
    fi
fi

echo -e "\n${PURPLE}${BOLD}Kurulum Sihirbazı tamamlandı. Teşekkür ederiz!${NC}\n"
