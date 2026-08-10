import os
import sys
import yaml
import secrets

# Ensure hermes-agent path is in sys.path
if os.path.exists(os.path.expanduser('~/.hermes/hermes-agent')):
    sys.path.append(os.path.expanduser('~/.hermes/hermes-agent'))
elif os.path.exists('/opt/hermes'):
    sys.path.append('/opt/hermes')

from plugins.dashboard_auth.basic import hash_password

config_path = os.environ.get('CONFIG_SRC', os.path.expanduser('~/app/config.yaml'))
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

# Ensure basic auth plugin is enabled
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

# Save back to CONFIG_SRC
with open(config_path, 'w') as f:
    yaml.safe_dump(cfg, f, default_flow_style=False)

# Also distribute to standard config directories to ensure dashboard loads it
for target_dir in [os.path.expanduser('~/.config/hermes'), os.path.expanduser('~/.hermes')]:
    os.makedirs(target_dir, exist_ok=True)
    with open(os.path.join(target_dir, 'config.yaml'), 'w') as f:
        yaml.safe_dump(cfg, f, default_flow_style=False)

print(f'SUCCESSFULLY_CONFIGURED_USER={username}')
