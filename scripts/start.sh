#!/bin/bash

TARGET_PORT=${PORT:-7860}

echo "=== VERİ GERİ YÜKLEME AŞAMASI ==="
if [ -n "$HF_TOKEN" ] && [ -f "$HOME/app/hermes_backup.tar.gz" ]; then
    echo "Eski yedek açılıyor..."
    tar -xzf "$HOME/app/hermes_backup.tar.gz" -C "$HOME/"
fi

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

username = os.environ.get('HERMES_DASHBOARD_BASIC_AUTH_USERNAME', ba_cfg.get('username', '')).strip()
if not username:
    username = 'admin'

password = os.environ.get('HERMES_DASHBOARD_BASIC_AUTH_PASSWORD', ba_cfg.get('password', '')).strip()
password_hash = os.environ.get('HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH', ba_cfg.get('password_hash', '')).strip()

if not password_hash:
    if not password:
        password = secrets.token_urlsafe(12)
        print(f'=== GENERATED_PASSWORD_START ===\n{password}\n=== GENERATED_PASSWORD_END ===')
    password_hash = hash_password(password)

ba_cfg['username'] = username
ba_cfg['password_hash'] = password_hash
ba_cfg['password'] = ''

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

# Bazı Hermes sürümleri config yolunu çevre değişkeninden okur:
export HERMES_CONFIG_PATH="$HOME/.hermes/config.yaml"

# Hugging Face Spaces üzerinde çalışabilmesi için:
# 1. Host 0.0.0.0 olmalı (dışarıdan erişim için).
# 2. Arka planda değil (&), ön planda çalışmalı (konteynerin kapanmaması için).
# 3. 'exec' kullanarak sinyal yönetimini kolaylaştırıyoruz.
# 4. --insecure parametresi 0.0.0.0 (localhost dışı) arayüzüne bağlanabilmek için zorunludur.
# 5. --no-open parametresi tarayıcıyı otomatik açmaya çalışmasını engeller.
exec hermes dashboard --port "$TARGET_PORT" --host 0.0.0.0 --insecure --no-open
