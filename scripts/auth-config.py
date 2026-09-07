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

# Dynamic Buzz Platform Configuration
buzz_relay_url = os.environ.get('BUZZ_RELAY_URL', '').strip()
buzz_cli_path = os.environ.get('BUZZ_CLI_PATH', '').strip()
buzz_channels_raw = os.environ.get('BUZZ_CHANNELS', '').strip()
buzz_home_channel = os.environ.get('BUZZ_HOME_CHANNEL', '').strip()
buzz_allowed_users_raw = os.environ.get('BUZZ_ALLOWED_USERS', '').strip()
buzz_allow_all_users_raw = os.environ.get('BUZZ_ALLOW_ALL_USERS', '').strip()
buzz_require_mention_raw = os.environ.get('BUZZ_REQUIRE_MENTION', '').strip()
buzz_enable_env = os.environ.get('BUZZ_ENABLE', '').strip()

gateway_cfg = cfg.setdefault('gateway', {})
platforms_cfg = gateway_cfg.setdefault('platforms', {})
buzz_cfg = platforms_cfg.setdefault('buzz', {})
buzz_extra = buzz_cfg.setdefault('extra', {})

# Determine if Buzz should be enabled
should_enable_buzz = False
if buzz_enable_env.lower() in ('true', '1', 'yes'):
    should_enable_buzz = True
elif buzz_relay_url or os.environ.get('BUZZ_PRIVATE_KEY') or buzz_channels_raw or buzz_home_channel:
    should_enable_buzz = True

if should_enable_buzz:
    buzz_cfg['enabled'] = True

    if buzz_relay_url:
        buzz_extra['relay_url'] = buzz_relay_url
    elif 'relay_url' not in buzz_extra:
        buzz_extra['relay_url'] = 'wss://relay.buzz.community'

    if buzz_cli_path:
        buzz_extra['cli_path'] = buzz_cli_path
    elif 'cli_path' not in buzz_extra:
        buzz_extra['cli_path'] = '/usr/local/bin/buzz'

    if buzz_channels_raw:
        if buzz_channels_raw.startswith('[') and buzz_channels_raw.endswith(']'):
            import json
            try:
                buzz_extra['channels'] = json.loads(buzz_channels_raw)
            except Exception:
                buzz_extra['channels'] = [c.strip() for c in buzz_channels_raw[1:-1].split(',') if c.strip()]
        else:
            buzz_extra['channels'] = [c.strip() for c in buzz_channels_raw.split(',') if c.strip()]
    elif 'channels' not in buzz_extra:
        buzz_extra['channels'] = []

    if buzz_home_channel:
        buzz_extra['home_channel'] = buzz_home_channel

    if buzz_allowed_users_raw:
        if buzz_allowed_users_raw.startswith('[') and buzz_allowed_users_raw.endswith(']'):
            import json
            try:
                buzz_extra['allowed_users'] = json.loads(buzz_allowed_users_raw)
            except Exception:
                buzz_extra['allowed_users'] = [u.strip() for u in buzz_allowed_users_raw[1:-1].split(',') if u.strip()]
        else:
            buzz_extra['allowed_users'] = [u.strip() for u in buzz_allowed_users_raw.split(',') if u.strip()]

    if buzz_allow_all_users_raw:
        buzz_extra['allow_all_users'] = buzz_allow_all_users_raw.lower() in ('true', '1', 'yes')
    elif 'allow_all_users' not in buzz_extra:
        buzz_extra['allow_all_users'] = False

    if buzz_require_mention_raw:
        buzz_extra['require_mention'] = buzz_require_mention_raw.lower() in ('true', '1', 'yes')
    elif 'require_mention' not in buzz_extra:
        buzz_extra['require_mention'] = True

# Save back to CONFIG_SRC
with open(config_path, 'w') as f:
    yaml.safe_dump(cfg, f, default_flow_style=False)

# Also distribute to standard config directories to ensure dashboard loads it
for target_dir in [os.path.expanduser('~/.config/hermes'), os.path.expanduser('~/.hermes')]:
    os.makedirs(target_dir, exist_ok=True)
    with open(os.path.join(target_dir, 'config.yaml'), 'w') as f:
        yaml.safe_dump(cfg, f, default_flow_style=False)

print(f'SUCCESSFULLY_CONFIGURED_USER={username}')
