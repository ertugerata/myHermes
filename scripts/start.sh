#!/bin/bash

SCRIPT_START_TS=$(date +%s)
TARGET_PORT=${PORT:-7860}

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

# Periodic backup loop running in the background
start_backup_loop() {
    echo "Periyodik yedekleme arka plan servisi başlatılıyor..."
    (
        # Wait 5 minutes before first backup
        sleep 300
        while true; do
            echo "=== PERİYODİK YEDEKLEME BAŞLADI ==="
            ./scripts/github-backup.sh backup
            sleep 1800
        done
    ) &
    BACKUP_LOOP_PID=$!
    echo "Yedekleme servis PID: $BACKUP_LOOP_PID"
}

# Trap handler for graceful shutdown and final backup
cleanup() {
    echo "=== ALINAN SİNYAL: GRACEFUL SHUTDOWN BAŞLATILIYOR ==="
    if [ -n "$BACKUP_LOOP_PID" ]; then
        kill "$BACKUP_LOOP_PID" 2>/dev/null || true
    fi
    echo "Son kez yedek alınıyor ve GitHub'a yükleniyor..."
    ./scripts/github-backup.sh backup
    if [ -n "$HERMES_PID" ]; then
        echo "Hermes durduruluyor..."
        kill -TERM "$HERMES_PID" 2>/dev/null || true
        wait "$HERMES_PID" 2>/dev/null || true
    fi
    exit 0
}

# Call github-backup restore to restore all configs and data at startup
./scripts/github-backup.sh restore

echo "=== AUTHENTICATION YAPILANDIRILIYOR ==="
# Python script to load, generate (if not provided), hash and modify config.yaml to configure username and password_hash
"$HOME/.hermes/hermes-agent/venv/bin/python" -c "
import os, sys, yaml
sys.path.append(os.path.expanduser('~/.hermes/hermes-agent'))
from plugins.dashboard_auth.basic import hash_password
import secrets

config_path = os.path.expanduser('~/app/config.yaml')
if not os.path.exists(config_path):
    config_path = 'config.yaml'
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
    echo "========================================================="
    echo ""
fi
rm -f auth_config_output.log

echo "=== CONFIG DOSYASI DOĞRULANIYOR ==="
# Konteyner ayağa kalkarken dosyanın tam konumunu ekrana basalım (Log takibi için)
CONFIG_SRC="$HOME/app/config.yaml"
if [ ! -f "$CONFIG_SRC" ]; then
    CONFIG_SRC="config.yaml"
fi

mkdir -p "$HOME/.config/hermes"
cp "$CONFIG_SRC" "$HOME/.config/hermes/config.yaml"

# Hermes default path matches HERMES_HOME (~/.hermes). Let's copy it there.
mkdir -p "$HOME/.hermes"
cp "$CONFIG_SRC" "$HOME/.hermes/config.yaml"
echo "✔ config.yaml doğru konumlarda (hem ~/.hermes/ hem de ~/.config/hermes/) hazır."

echo "=== HERMES AGENT BAŞLATILIYOR ==="
echo "Dinlenen Port: $TARGET_PORT"
PRE_START_ELAPSED=$(( $(date +%s) - SCRIPT_START_TS ))
echo "ℹ Buraya kadar (DNS + yedek geri yükleme + auth ayarı) geçen süre: ${PRE_START_ELAPSED}sn"

# Bazı Hermes sürümleri config yolunu çevre değişkeninden okur:
export HERMES_CONFIG_PATH="$HOME/.hermes/config.yaml"

# Register trap for SIGTERM and SIGINT
trap cleanup SIGTERM SIGINT

# Start the periodic backup loop in background
start_backup_loop

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
