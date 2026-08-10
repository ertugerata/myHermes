#!/bin/bash
set -uo pipefail

# Sourcing local .env file if it exists so those variables are exported to the shell environment
if [ -f "$HOME/app/.env" ]; then
    echo "✔ Yerel .env dosyası tespit edildi, çevre değişkenleri yükleniyor..."
    set +u
    set -a
    source "$HOME/app/.env"
    set +a
    set -u
fi

export PATH="/opt/hermes/bin:/opt/hermes/.venv/bin:$HOME/.local/bin:$PATH"
export HERMES_HOME="$HOME/.hermes"
export HERMES_WRITE_SAFE_ROOT="$HOME/.hermes"
export HERMES_LAZY_INSTALL_TARGET="$HOME/.hermes/lazy-packages"
export CONFIG_SRC="$HOME/app/config.yaml"
export NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--require $HOME/app/scripts/dns-fix.cjs"
export PYTHONPATH="$HOME/app/scripts${PYTHONPATH:+:$PYTHONPATH}"

# Determine Python binary path dynamically
if [ -f "/opt/hermes/.venv/bin/python" ]; then
    HERMES_PYTHON="/opt/hermes/.venv/bin/python"
elif [ -f "$HOME/.hermes/hermes-agent/venv/bin/python" ]; then
    HERMES_PYTHON="$HOME/.hermes/hermes-agent/venv/bin/python"
else
    HERMES_PYTHON="python3"
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

echo "=== STARTING SUPERVISORD ==="
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
