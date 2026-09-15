"""Print staging commands only; no network access, secrets, or auto-execution."""
import base64
import hashlib
from pathlib import Path

root = Path(__file__).resolve().parent
files = ('service.sh', 'worker.sh', 'health.sh', 'profiles.example.sh')
target = '/opt/adguardvpn_cli/article-stage'
print('# Paste executable lines into Keenetic Web CLI one at a time.')
print('# Existing article-stage files with these names will be overwritten.')
print('exec sh -c "export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin; '
      f'umask 077; mkdir -p {target}"')
for name in files:
    data = (root / name).read_bytes()
    encoded = base64.b64encode(data).decode('ascii')
    print(f'# SHA256 {name}: {hashlib.sha256(data).hexdigest()}')
    print('exec sh -c "umask 077; '
          f"printf '%s' '{encoded}' | /opt/bin/busybox base64 -d "
          f'> {target}/{name}"')
