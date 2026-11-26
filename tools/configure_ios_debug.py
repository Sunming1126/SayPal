"""Install local test credentials for iOS Debug builds only."""
import base64
import json
import os
from pathlib import Path
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    config = json.loads((root / '.local/saypal-online.json').read_text())
    keys = ('SAYPAL_CHAT_TRANSPORT', 'SAYPAL_API_BASE_URL', 'SAYPAL_CHAT_TOKEN')
    if any(not isinstance(config.get(key), str) or not config[key] for key in keys):
        raise SystemExit('Incomplete local online configuration.')
    defines = ','.join(base64.b64encode(f'{key}={config[key]}'.encode()).decode() for key in keys)
    target = root / 'ios/Flutter/SayPal.local.xcconfig'
    fd, name = tempfile.mkstemp(dir=target.parent, prefix='.saypal-')
    try:
        with os.fdopen(fd, 'w') as output:
            output.write('// Private local test configuration; included by Debug.xcconfig only.\n')
            output.write('DART_DEFINES = ' + defines + '\n')
        os.replace(name, target)
    finally:
        if os.path.exists(name):
            os.unlink(name)
    print('Configured iOS Debug builds automatically (mode 600). Release/Profile are unchanged.')


if __name__ == '__main__':
    main()
