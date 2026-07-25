#!/bin/bash
set -uo pipefail

SCRIPT_START_TS=$(date +%s)
TARGET_PORT=${PORT:-7860}

# Save backup environment variables to a secure file so manual executions from terminal/subprocesses have access to them
cat << EOF > "$HOME/.backup_env"
export GITHUB_BACKUP_REPO="${GITHUB_BACKUP_REPO:-${BACKUP_REPO:-}}"
export GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
export BACKUP_REPO="${BACKUP_REPO:-${GITHUB_BACKUP_REPO:-}}"
export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
EOF
chmod 600 "$HOME/.backup_env"

# WORKDIR ($HOME/app) her zaman CMD'nin çalıştığı dizin olduğu için config.yaml'ın
# konumu tektir; artık ne bash ne de Python tarafında ayrı "önce şurayı dene,
# olmazsa burayı dene" mantığına gerek yok. Tek kaynak burada tanımlanır ve
# Python bloğuna CONFIG_SRC ortam değişkeniyle aktarılır.
CONFIG_SRC="$HOME/app/config.yaml"
export CONFIG_SRC

# Trap'i en başta kaydediyoruz ki restore/backup_loop başlamadan önce gelen
# bir SIGTERM/SIGINT'te de düzgün kapanabilelim.
cleanup() {
    echo "=== ALINAN SİNYAL: GRACEFUL SHUTDOWN BAŞLATILIYOR ==="
    if [ -n "${BACKUP_LOOP_PID:-}" ]; then
        echo "Yedekleme döngüsü durduruluyor..."
        kill "$BACKUP_LOOP_PID" 2>/dev/null || true
    fi
    if [ -n "${HERMES_PID:-}" ]; then
        echo "Hermes durduruluyor..."
        kill -TERM "$HERMES_PID" 2>/dev/null || true
        wait "$HERMES_PID" 2>/dev/null || true
    fi
    echo "=== KAPANMADAN ÖNCE SON YEDEKLEME YAPILIYOR ==="
    bash "$HOME/app/scripts/github-backup.sh" backup
    exit 0
}
trap cleanup SIGTERM SIGINT

echo "=== DNS HAZIRLIĞI VE ÖNÇÖZÜMLEME ==="
# Runs dns-resolve.py to pre-resolve blocked domains via DNS-over-HTTPS.
# It will write resolved mappings to /tmp/dns-resolved.json
python3 scripts/dns-resolve.py /tmp/dns-resolved.json &
DNS_PID=$!
echo "DNS çözücü PID: $DNS_PID"

# Node.js süreçleri için dns-fix.cjs yüklenmesi sağlanıyor.
export NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--require $HOME/app/scripts/dns-fix.cjs"

# Python süreçleri için sitecustomize.py yüklenmesi sağlanıyor.
# sitecustomize.py'ın otomatik olarak yüklenebilmesi için scripts dizini PYTHONPATH'e eklenir.
export PYTHONPATH="$HOME/app/scripts${PYTHONPATH:+:$PYTHONPATH}"
echo "✔ PYTHONPATH ayarlandı: $PYTHONPATH"

# github-backup.sh GitHub'a (ağ) eriştiği için, DNS ön-çözümlemesinin bitmesini
# bekliyoruz — aksi halde blocked domain'ler henüz çözülmemiş olabilir.
echo "DNS ön-çözümlemesi bekleniyor..."
wait "$DNS_PID"
echo "✔ DNS ön-çözümlemesi tamamlandı."

echo "=== GITHUB YEDEK GERİ YÜKLEME BAŞLATILIYOR ==="
# Başlangıçta github-backup scriptini çalıştırarak varsa yedeklerimizi geri yüklüyoruz.
bash "$HOME/app/scripts/github-backup.sh" restore

# Periyodik yedekleme döngüsü (Varsayılan olarak 3 saatte bir çalışır, istenirse BACKUP_INTERVAL ile değiştirilebilir veya kapatılabilir)
backup_loop() {
    # Varsayılan 3 saat (10800 saniye). BACKUP_INTERVAL saniye cinsinden veya 'disabled'/'0'/'false' olabilir.
    local INTERVAL="${BACKUP_INTERVAL:-10800}"

    if [ "$INTERVAL" = "disabled" ] || [ "$INTERVAL" = "0" ] || [ "$INTERVAL" = "false" ]; then
        echo "ℹ Periyodik yedekleme devre dışı bırakıldı. Sadece manuel veya graceful shutdown sırasında yedeklenecek."
        return 0
    fi

    # Sayısal değer olup olmadığını kontrol edelim
    if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]]; then
        echo "⚠️ Geçersiz BACKUP_INTERVAL değeri ('$INTERVAL'). Varsayılan 3 saat (10800 sn) kullanılacak."
        INTERVAL=10800
    fi

    echo "ℹ Periyodik yedekleme her $INTERVAL saniyede bir çalışacak şekilde ayarlandı."
    while true; do
        sleep "$INTERVAL"
        echo "=== PERİYODİK YEDEKLEME BAŞLATILIYOR ==="
        bash "$HOME/app/scripts/github-backup.sh" backup
    done
}

echo "=== AUTHENTICATION YAPILANDIRILIYOR ==="
# Python script to load, generate (if not provided), hash and modify config.yaml to configure username and password_hash
"$HOME/.hermes/hermes-agent/venv/bin/python" -c "
import os, sys, yaml
sys.path.append(os.path.expanduser('~/.hermes/hermes-agent'))
from plugins.dashboard_auth.basic import hash_password
import secrets

config_path = os.environ['CONFIG_SRC']
with open(config_path, 'r') as f:
    cfg = yaml.safe_load(f) or {}

db_cfg = cfg.setdefault('dashboard', {})
ba_cfg = db_cfg.setdefault('basic_auth', {})

username = os.environ.get('HERMES_DASHBOARD_BASIC_AUTH_USERNAME', '').strip()
if not username:
    username = ba_cfg.get('username', '').strip()
if not username:
    username = 'admin'

env_password = os.environ.get('HERMES_DASHBOARD_BASIC_AUTH_PASSWORD', '').strip()
env_password_hash = os.environ.get('HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH', '').strip()

if env_password_hash:
    password_hash = env_password_hash
elif env_password:
    password_hash = hash_password(env_password)
else:
    password_hash = ba_cfg.get('password_hash', '').strip()
    if not password_hash:
        cfg_password = ba_cfg.get('password', '').strip()
        if cfg_password:
            password_hash = hash_password(cfg_password)
        else:
            password = secrets.token_urlsafe(12)
            print(f'=== GENERATED_PASSWORD_START ===\n{password}\n=== GENERATED_PASSWORD_END ===')
            password_hash = hash_password(password)

ba_cfg['username'] = username
ba_cfg['password_hash'] = password_hash
ba_cfg['password'] = ''

# Ensure the basic authentication plugin is enabled and not disabled (Fix for #54489)
plugins_cfg = cfg.setdefault('plugins', {})

disabled_list = plugins_cfg.get('disabled')
if isinstance(disabled_list, list):
    if 'basic' in disabled_list:
        disabled_list.remove('basic')
elif disabled_list is not None:
    plugins_cfg['disabled'] = []
else:
    plugins_cfg['disabled'] = []

enabled_list = plugins_cfg.get('enabled')
if isinstance(enabled_list, list):
    if 'basic' not in enabled_list:
        enabled_list.append('basic')
else:
    plugins_cfg['enabled'] = ['basic']

with open(config_path, 'w') as f:
    yaml.safe_dump(cfg, f, default_flow_style=False)

print(f'SUCCESSFULLY_CONFIGURED_USER={username}')
" > auth_config_output.log 2>&1

cat auth_config_output.log

# Extract generated password if any and print nice message
if grep -q "=== GENERATED_PASSWORD_START ===" auth_config_output.log; then
    GEN_USER=$(grep "SUCCESSFULLY_CONFIGURED_USER=" auth_config_output.log | cut -d'=' -f2)
    GEN_PWD=$(sed -n '/=== GENERATED_PASSWORD_START ===/,/=== GENERATED_PASSWORD_END ===/{ /===/d; p; }' auth_config_output.log)
    echo ""
    echo "========================================================="
    echo "🔑 DEFAULT DASHBOARD CREDENTIALS GENERATED:"
    echo "   Username: $GEN_USER"
    echo "   Password: $GEN_PWD"
    echo "   (Bu parola sadece konsol loguna yazılır; kalıcı bir volume"
    echo "    kullanılmıyorsa her yeniden başlatmada YENİDEN üretilir.)"
    echo "========================================================="
    echo ""
fi
rm -f auth_config_output.log

echo "=== CONFIG DOSYASI DAĞITILIYOR ==="
# Auth bilgisiyle güncellenen tek config.yaml (CONFIG_SRC), hermes-agent'ın
# aradığı iki olası konuma da kopyalanır. Hangi konum kullanılırsa kullanılsın
# içerik aynı kaynaktan geldiği için tekrar/uyuşmazlık riski yok.
for target_dir in "$HOME/.config/hermes" "$HOME/.hermes"; do
    mkdir -p "$target_dir"
    cp "$CONFIG_SRC" "$target_dir/config.yaml"
done
echo "✔ config.yaml doğru konumlarda (hem ~/.hermes/ hem de ~/.config/hermes/) hazır."

echo "=== HERMES AGENT BAŞLATILIYOR ==="
echo "Dinlenen Port: $TARGET_PORT"
PRE_START_ELAPSED=$(( $(date +%s) - SCRIPT_START_TS ))
echo "ℹ Buraya kadar (DNS + auth ayarı) geçen süre: ${PRE_START_ELAPSED}sn"

# Bazı Hermes sürümleri config yolunu çevre değişkeninden okur:
export HERMES_CONFIG_PATH="$HOME/.hermes/config.yaml"

# Periyodik yedekleme döngüsünü arka planda başlatıyoruz
backup_loop &
BACKUP_LOOP_PID=$!
echo "Periyodik yedekleme döngüsü başlatıldı, PID: $BACKUP_LOOP_PID"

# Hugging Face Spaces üzerinde çalışabilmesi için:
# 1. Host 0.0.0.0 olmalı (dışarıdan erişim için).
# 2. Arka planda çalıştırıp bash ile sinyal yakalıyoruz (trap).
# 3. --no-open parametresi tarayıcıyı otomatik açmaya çalışmasını engeller.
hermes dashboard --port "$TARGET_PORT" --host 0.0.0.0 --no-open &
HERMES_PID=$!

echo "Hermes Dashboard PID: $HERMES_PID"

# Wait for hermes dashboard process
wait "$HERMES_PID"
echo "Hermes durdu veya sinyal alındı. Çıkılıyor."