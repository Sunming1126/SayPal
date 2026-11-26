"""Fetch only the native-client test token over SSH; never print its value."""
import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
REMOTE = r"""sudo -n python3 - <<'PY'
import json, shlex
from pathlib import Path
values = {}
for line in Path('/opt/saypal/voice/shared/.env').read_text().splitlines():
    line = line.strip().removeprefix('export ')
    if not line or line.startswith('#') or '=' not in line:
        continue
    key, raw = line.split('=', 1)
    if key.strip() == 'SAYPAL_CHAT_TOKEN':
        parts = shlex.split(raw, comments=True)
        values[key.strip()] = ' '.join(parts)
if not values.get('SAYPAL_CHAT_TOKEN'):
    raise SystemExit('SAYPAL_CHAT_TOKEN is missing')
print(json.dumps(values))
PY"""


def main():
    result = subprocess.run(
        ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12',
         'onesay-server', REMOTE], capture_output=True, text=True, timeout=30,
    )
    if result.returncode:
        raise SystemExit('SSH configuration fetch failed; no credentials were printed.')
    values = json.loads(result.stdout)
    token = values.get('SAYPAL_CHAT_TOKEN')
    if not isinstance(token, str) or not token:
        raise SystemExit('Server did not supply a native-client token.')
    config = {
        'SAYPAL_CHAT_TRANSPORT': 'websocket',
        'SAYPAL_API_BASE_URL': 'https://onesay.top/saypal/voice',
        'SAYPAL_CHAT_TOKEN': token,
    }
    directory = ROOT / '.local'
    directory.mkdir(mode=0o700, exist_ok=True)
    os.chmod(directory, 0o700)
    target = directory / 'saypal-online.json'
    fd, name = tempfile.mkstemp(dir=directory, prefix='.online-')
    try:
        with os.fdopen(fd, 'w') as output:
            json.dump(config, output, ensure_ascii=False, indent=2)
            output.write('\n')
        os.replace(name, target)
    finally:
        if os.path.exists(name):
            os.unlink(name)
    print(f'Saved {target} (mode 600); account service remains unconfigured.')


if __name__ == '__main__':
    main()
