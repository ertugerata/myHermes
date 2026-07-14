#!/bin/bash

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

# Helper function to perform git backup
do_git_backup() {
    if [ -d "$HOME/hermes_backup_git" ]; then
        echo "Yedek dosyaları hazırlanıyor..."

        # Sync .hermes to the git repo
        mkdir -p "$HOME/hermes_backup_git/.hermes"

        # Copy everything in ~/.hermes except lock files/sockets
        cp -rf "$HOME/.hermes/"* "$HOME/hermes_backup_git/.hermes/" 2>/dev/null || true

        # Remove large binary directories to stay within GitHub file size limits
        rm -rf "$HOME/hermes_backup_git/.hermes/bin"
        rm -rf "$HOME/hermes_backup_git/.hermes/node"
        rm -rf "$HOME/hermes_backup_git/.hermes/hermes-agent"
        rm -rf "$HOME/hermes_backup_git/.hermes/venv"
        rm -rf "$HOME/hermes_backup_git/.hermes/node_modules"

        # Sync config.yaml if it exists
        if [ -f "$HOME/app/config.yaml" ]; then
            cp -f "$HOME/app/config.yaml" "$HOME/hermes_backup_git/config.yaml"
        fi

        cd "$HOME/hermes_backup_git"

        # Ensure git identity is set
        git config user.name "Hermes Backup Bot"
        git config user.email "hermes-backup-bot@users.noreply.github.com"

        # Ensure .gitignore exists inside the repo to ignore large binaries
        cat << 'EOF' > .gitignore
# Large binary runtimes and environments
.hermes/bin/
.hermes/node/
.hermes/hermes-agent/
.hermes/venv/
.hermes/node_modules/
*.log
*.tmp
*.lock
EOF

        # Untrack any accidentally tracked large files/directories
        git rm -r --cached .hermes/bin .hermes/node .hermes/hermes-agent .hermes/venv .hermes/node_modules 2>/dev/null || true

        # Add changes
        git add .

        # Check if there are changes to commit
        if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
            echo "Yeni değişiklikler algılandı. Yedek commit ediliyor..."
            git commit -m "Automated backup: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

            CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
                CURRENT_BRANCH="main"
                git checkout -b main 2>/dev/null || true
            fi

            echo "Yedek GitHub'a yükleniyor ($CURRENT_BRANCH)..."
            git push origin "$CURRENT_BRANCH" > /tmp/git_push.log 2>&1
            PUSH_STATUS=$?
            if [ $PUSH_STATUS -eq 0 ]; then
                echo "✔ Yedek başarıyla GitHub deposuna gönderildi."
            else
                echo "❌ HATA: Yedek GitHub'a gönderilemedi."
                if [ -n "$GIT_TOKEN" ]; then
                    sed "s/$GIT_TOKEN/[MASKED_TOKEN]/g" /tmp/git_push.log
                else
                    cat /tmp/git_push.log
                fi
            fi
            rm -f /tmp/git_push.log
        else
            echo "Yedeklemede yeni değişiklik yok."
        fi
        cd "$HOME/app"
    fi
}

# Periodic backup loop running in the background
start_backup_loop() {
    if [ -d "$HOME/hermes_backup_git" ]; then
        echo "Periyodik yedekleme arka plan servisi başlatılıyor..."
        (
            # Wait 5 minutes before first backup
            sleep 300
            while true; do
                echo "=== PERİYODİK YEDEKLEME BAŞLADI ==="
                do_git_backup
                sleep 1800
            done
        ) &
        BACKUP_LOOP_PID=$!
        echo "Yedekleme servis PID: $BACKUP_LOOP_PID"
    fi
}

# Trap handler for graceful shutdown and final backup
cleanup() {
    echo "=== ALINAN SİNYAL: GRACEFUL SHUTDOWN BAŞLATILIYOR ==="
    if [ -n "$BACKUP_LOOP_PID" ]; then
        kill "$BACKUP_LOOP_PID" 2>/dev/null || true
    fi
    if [ -d "$HOME/hermes_backup_git" ]; then
        echo "Son kez yedek alınıyor ve GitHub'a yükleniyor..."
        do_git_backup
    fi
    if [ -n "$HERMES_PID" ]; then
        echo "Hermes durduruluyor..."
        kill -TERM "$HERMES_PID" 2>/dev/null || true
        wait "$HERMES_PID" 2>/dev/null || true
    fi
    exit 0
}

echo "=== VERİ GERİ YÜKLEME AŞAMASI (GITHUB BACKUP) ==="
REPO_URL="${GITHUB_BACKUP_REPO:-$BACKUP_REPO}"
GIT_TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"

if [ -n "$REPO_URL" ]; then
    echo "GitHub yedekleme aktif..."
    AUTH_REPO_URL="$REPO_URL"
    if [ -n "$GIT_TOKEN" ]; then
        if [[ "$REPO_URL" =~ ^https:// ]]; then
            CLEAN_URL="${REPO_URL#https://}"
            AUTH_REPO_URL="https://${GIT_TOKEN}@${CLEAN_URL}"
        else
            AUTH_REPO_URL="https://${GIT_TOKEN}@${REPO_URL}"
        fi
    fi

    BACKUP_GIT_DIR="$HOME/hermes_backup_git"
    rm -rf "$BACKUP_GIT_DIR"

    echo "Yedek deposu klonlanıyor..."
    git clone --depth 1 "$AUTH_REPO_URL" "$BACKUP_GIT_DIR" > /tmp/git_clone.log 2>&1
    CLONE_STATUS=$?
    if [ $CLONE_STATUS -eq 0 ]; then
        echo "✔ Yedek deposu başarıyla klonlandı."

        # Configure git identity inside the cloned repo
        cd "$BACKUP_GIT_DIR"
        git config user.name "Hermes Backup Bot"
        git config user.email "hermes-backup-bot@users.noreply.github.com"
        cd "$HOME/app"

        # Restore .hermes if it exists
        if [ -d "$BACKUP_GIT_DIR/.hermes" ]; then
            echo "Yedek veriler geri yükleniyor (.hermes)..."
            mkdir -p "$HOME/.hermes"
            cp -rf "$BACKUP_GIT_DIR/.hermes/"* "$HOME/.hermes/" 2>/dev/null || true
            echo "✔ .hermes geri yüklendi."
        fi

        # Restore config.yaml if it exists
        if [ -f "$BACKUP_GIT_DIR/config.yaml" ]; then
            echo "Yedek config.yaml geri yükleniyor..."
            cp -f "$BACKUP_GIT_DIR/config.yaml" "$HOME/app/config.yaml"
            echo "✔ config.yaml geri yüklendi."
        fi

        # Backward compatibility with tar.gz backup
        if [ -f "$BACKUP_GIT_DIR/hermes_backup.tar.gz" ]; then
            echo "Eski zip yedeği açılıyor (hermes_backup.tar.gz)..."
            tar -xzf "$BACKUP_GIT_DIR/hermes_backup.tar.gz" -C "$HOME/"
            echo "✔ hermes_backup.tar.gz başarıyla açıldı."
        fi
    else
        echo "❌ HATA: Yedek deposu klonlanamadı."
        if [ -n "$GIT_TOKEN" ]; then
            sed "s/$GIT_TOKEN/[MASKED_TOKEN]/g" /tmp/git_clone.log
        else
            cat /tmp/git_clone.log
        fi
    fi
    rm -f /tmp/git_clone.log
else
    echo "Bilgilendirme: GITHUB_BACKUP_REPO tanımlı değil. GitHub yedekleme aktif edilmedi."
    if [ -n "$HF_TOKEN" ] && [ -f "$HOME/app/hermes_backup.tar.gz" ]; then
        echo "Eski yerel yedek açılıyor..."
        tar -xzf "$HOME/app/hermes_backup.tar.gz" -C "$HOME/"
    fi
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
