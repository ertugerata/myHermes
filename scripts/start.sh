#!/bin/bash
set -uo pipefail

SCRIPT_START_TS=$(date +%s)
TARGET_PORT=${PORT:-7860}

# Ensure PATH and home directories are correctly configured
export PATH="/opt/hermes/bin:/opt/hermes/.venv/bin:$HOME/.local/bin:$PATH"
export HERMES_HOME="$HOME/.hermes"
export HERMES_WRITE_SAFE_ROOT="$HOME/.hermes"
export HERMES_LAZY_INSTALL_TARGET="$HOME/.hermes/lazy-packages"
export CONFIG_SRC="$HOME/app/config.yaml"

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

# Periyodik yedekleme döngüsü (Her 2 saatte bir çalışır)
backup_loop() {
    while true; do
        sleep 7200
        echo "=== PERİYODİK YEDEKLEME BAŞLATILIYOR ==="
        bash "$HOME/app/scripts/github-backup.sh" backup
    done
}

echo "=== AUTHENTICATION YAPILANDIRILIYOR ==="
# Determine Python binary path dynamically
if [ -f "/opt/hermes/.venv/bin/python" ]; then
    HERMES_PYTHON="/opt/hermes/.venv/bin/python"
elif [ -f "$HOME/.hermes/hermes-agent/venv/bin/python" ]; then
    HERMES_PYTHON="$HOME/.hermes/hermes-agent/venv/bin/python"
else
    HERMES_PYTHON="python3"
fi

echo "=== .ENV DOSYASI AYARLANIYOR VE SENKRONİZE EDİLİYOR ==="
# Sourcing local .env file if it exists so those variables are exported to the shell environment
if [ -f "$HOME/app/.env" ]; then
    echo "✔ Yerel .env dosyası tespit edildi, çevre değişkenleri yükleniyor..."
    set +u
    set -a
    source "$HOME/app/.env"
    set +a
    set -u
fi

# Hedef dizinleri oluştur
mkdir -p "$HOME/.hermes" "$HOME/.config/hermes"

# Eğer yerel .env varsa ~/.hermes/.env konumuna kopyala (başlangıç için)
if [ -f "$HOME/app/.env" ] && [ ! -f "$HOME/.hermes/.env" ]; then
    cp "$HOME/app/.env" "$HOME/.hermes/.env"
fi

# Python ile çevre değişkenlerini ve .env dosyasını birleştir
"$HERMES_PYTHON" -c "
import os
env_path = os.path.expanduser('~/.hermes/.env')

env_dict = {}
if os.path.exists(env_path):
    with open(env_path, 'r', encoding='utf-8') as f:
        for line in f:
            line_str = line.strip()
            if line_str and not line_str.startswith('#') and '=' in line_str:
                parts = line_str.split('=', 1)
                k = parts[0].strip()
                v = parts[1].strip()
                env_dict[k] = v

keys_to_sync = [
    'OPENROUTER_API_KEY', 'OPENAI_API_KEY', 'ANTHROPIC_API_KEY',
    'DEEPSEEK_API_KEY', 'GROQ_API_KEY', 'HF_TOKEN', 'GITHUB_TOKEN',
    'GITHUB_BACKUP_REPO', 'BACKUP_INTERVAL',
    'HERMES_DASHBOARD_BASIC_AUTH_USERNAME', 'HERMES_DASHBOARD_BASIC_AUTH_PASSWORD',
    'HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH', 'PORT'
]

for k, v in os.environ.items():
    if k.startswith('HERMES_') or k.endswith('_API_KEY') or k.endswith('_TOKEN') or k in keys_to_sync:
        env_dict[k] = v

with open(env_path, 'w', encoding='utf-8') as f:
    f.write('# Automatically managed by start.sh\n')
    for k, v in sorted(env_dict.items()):
        f.write(f'{k}={v}\n')
"

# ~/.hermes/.env dosyasını ~/.config/hermes/.env konumuna da senkronize et
cp "$HOME/.hermes/.env" "$HOME/.config/hermes/.env"
echo "✔ .env dosyaları başarıyla ~/.hermes/.env ve ~/.config/hermes/.env konumlarına senkronize edildi."

# Python script to load, generate (if not provided), hash and modify config.yaml to configure username and password_hash
"$HERMES_PYTHON" -c "
import os, sys, yaml
if os.path.exists(os.path.expanduser('~/.hermes/hermes-agent')):
    sys.path.append(os.path.expanduser('~/.hermes/hermes-agent'))
elif os.path.exists('/opt/hermes'):
    sys.path.append('/opt/hermes')
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