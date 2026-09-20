"""Package explicit release components; never include workspace state or signing secrets."""
from pathlib import Path
import hashlib, json, plistlib, zipfile, stat, shutil

root = Path(__file__).resolve().parents[1]
out = root / 'dist'
app = root / 'Prisma.app'
app_version = plistlib.loads((app/'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
chrome_version = json.loads((root/'ChromeExtension/manifest.json').read_text())['version']
blocked = {'.pem', '.key', '.p12', '.p8', '.mobileprovision'}

def add(zip_file, path, name):
    assert path.is_file() and not path.is_symlink(), path
    assert path.suffix.lower() not in blocked and path.name != '.DS_Store', path
    info = zipfile.ZipInfo.from_file(path, name)
    info.create_system = 3
    # Drop local xattrs and preserve only the executable permission when needed.
    mode = 0o755 if path.stat().st_mode & stat.S_IXUSR else 0o644
    info.external_attr = (stat.S_IFREG | mode) << 16
    zip_file.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)

def tree(zip_file, folder, prefix):
    for path in sorted(folder.rglob('*')):
        if path.is_file() and path.name != '.DS_Store':
            add(zip_file, path, str(Path(prefix)/path.relative_to(folder)))

app_zip = out/f'Prisma-{app_version}-macOS-arm64.zip'
with zipfile.ZipFile(app_zip,'w') as z:
    tree(z, app, 'Prisma.app')
    for doc in ['README.md','README.ja.md','LICENSE','PRIVACY.md','CHANGELOG.md','CONTRIBUTING.md','SECURITY.md']:
        add(z,root/doc,doc)
    tree(z,root/'docs','docs')
    add(z,root/'Assets/Prism-preview.png','Assets/Prism-preview.png')
chrome_zip = out/f'Prisma-Tabs-{chrome_version}.zip'
with zipfile.ZipFile(chrome_zip,'w') as z:
    tree(z,root/'ChromeExtension','ChromeExtension')
    z.writestr('README.md',(root/'docs/chrome.md').read_text().replace('../PRIVACY.md','PRIVACY.md'),compress_type=zipfile.ZIP_DEFLATED)
    add(z,root/'LICENSE','LICENSE')
    add(z,root/'PRIVACY.md','PRIVACY.md')
shutil.copy2(root/'Prisma Auto.streamDeckProfile',out/'Prisma Auto.streamDeckProfile')
plugin = out/'io.github.kory-.prisma.streamDeckPlugin'
assert plugin.is_file()
files = [app_zip,chrome_zip,plugin,out/'Prisma Auto.streamDeckProfile']
for path in files:
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None, path
        assert not any(Path(name).suffix.lower() in blocked or name.startswith('__MACOSX/') for name in z.namelist()), path
(out/'SHA256SUMS.txt').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in files))
for path in files: print(f'{path.name}: {path.stat().st_size:,} bytes')
print('PASS: release archives, permissions, checksums and forbidden-file checks')
