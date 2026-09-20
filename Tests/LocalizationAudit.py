from pathlib import Path
import json, re, subprocess, plistlib

root = Path(__file__).resolve().parent.parent
def strings(path):
    return json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))

native = {lang: strings(root / f'Source/Resources/{lang}.lproj/Localizable.strings') for lang in ['en', 'ja']}
assert native['en'].keys() == native['ja'].keys()
for key in native['en']:
    placeholders = lambda s: re.findall(r'%(?:\d+\$)?(?:lu|ld|@|d|f)', s)
    assert placeholders(native['en'][key]) == placeholders(native['ja'][key]), key
for path in (root / 'Source').glob('*'):
    if path.suffix not in ['.h', '.mm']:
        continue
    for key in re.findall(r'PL\(@"((?:[^"\\]|\\.)*)"\)', path.read_text()):
        assert key.replace('\\n', '\n') in native['en'], (path.name, key)
for lang in ['en', 'ja']:
    assert strings(root / f'Source/Resources/{lang}.lproj/InfoPlist.strings')['NSAudioCaptureUsageDescription']
info = plistlib.loads((root / 'Source/Info.plist').read_bytes())
assert info['CFBundleDevelopmentRegion'] == 'en' and set(info['CFBundleLocalizations']) == {'en', 'ja'}

chrome = root / 'ChromeExtension'
catalogs = {lang: json.loads((chrome / f'_locales/{lang}/messages.json').read_text()) for lang in ['en', 'ja']}
assert catalogs['en'].keys() == catalogs['ja'].keys()
manifest = json.loads((chrome / 'manifest.json').read_text())
assert manifest['default_locale'] == 'en' and manifest['description'] == '__MSG_extension_description__'
for path in chrome.iterdir():
    if path.suffix not in ['.js', '.html']:
        continue
    keys = re.findall(r"\bt\('([^']+)'", path.read_text()) + re.findall(r'data-i18n(?:-title|-aria)?="([^"]+)"', path.read_text())
    for key in keys:
        assert key in catalogs['en'], (path.name, key)
for key in catalogs['en']:
    assert re.findall(r'\$\d', catalogs['en'][key]['message']) == re.findall(r'\$\d', catalogs['ja'][key]['message']), key

deck = root / 'io.github.kory-.prisma.sdPlugin'
catalogs = {lang: json.loads((deck / f'{lang}.json').read_text()) for lang in ['en', 'ja']}
assert catalogs['en']['Localization'].keys() == catalogs['ja']['Localization'].keys()
manifest = json.loads((deck / 'manifest.json').read_text())
for action in manifest['Actions']:
    for lang in catalogs:
        assert catalogs[lang][action['UUID']]['Name']
        if 'Encoder' in action:
            assert catalogs[lang][action['UUID']]['Encoder']['TriggerDescription'].keys() == action['Encoder']['TriggerDescription'].keys()
for key in re.findall(r'text\("([^"]+)"\)', (root / 'Source/StreamDeck.swift').read_text()):
    assert key in catalogs['en']['Localization'], key
print(f'PASS: {len(native["en"])} native strings, permission resources, Chrome catalogs and Stream Deck manifest/runtime translations have complete matching keys and placeholders')
