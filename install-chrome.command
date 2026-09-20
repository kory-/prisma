#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 - <<'PY'
import json, base64, hashlib, shutil
from pathlib import Path
root=Path.cwd(); app=(root/'Prisma.app').resolve(); extension=root/'ChromeExtension'
host=app/'Contents/MacOS/PrismaChromeHost'
if not host.is_file(): raise SystemExit('同じフォルダにPrisma.appを置いてから実行してください。')
manifest=json.loads((extension/'manifest.json').read_text())
identifier=''.join(chr(97+int(c,16)) for c in hashlib.sha256(base64.b64decode(manifest['key'])).hexdigest()[:32])
support=Path.home()/'Library/Application Support'
destination=support/'Prisma/ChromeExtension'
shutil.copytree(extension,destination,dirs_exist_ok=True)
for obsolete in ["offscreen.html", "offscreen.js", "audio-core.mjs"]:
    (destination/obsolete).unlink(missing_ok=True)
hosts=support/'Google/Chrome/NativeMessagingHosts';hosts.mkdir(parents=True,exist_ok=True)
config={'name':'local.prisma.chrome','description':'Prisma Tabs','path':str(host),'type':'stdio','allowed_origins':[f'chrome-extension://{identifier}/']}
(hosts/'local.prisma.chrome.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n')
print('PrismaとChromeをつなぐ準備ができました。')
print('Chromeで chrome://extensions を開き、デベロッパーモードをオンにします。')
print('「パッケージ化されていない拡張機能を読み込む」で次のフォルダを選んでください：')
print(destination)
PY
