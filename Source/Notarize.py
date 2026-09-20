"""Sign, submit once, resume, and verify Prisma's actual notarization result.

Credentials are read by notarytool from an explicitly named Keychain profile.
No password, private signing key, or API token is accepted or written here.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '.build/notarization'
STATE = WORK / 'state.json'
PLUGIN = 'io.github.kory-.prisma.sdPlugin'

def run(*args):
    result = subprocess.run([str(a) for a in args], cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f'{Path(str(args[0])).name} failed ({result.returncode}):\n{result.stdout}{result.stderr}')
    return result.stdout

def write_state(state):
    WORK.mkdir(parents=True, exist_ok=True)
    temporary = STATE.with_suffix('.tmp')
    temporary.write_text(json.dumps(state, indent=2) + '\n')
    temporary.replace(STATE)

def read_state():
    if not STATE.exists():
        raise RuntimeError('Run prepare first.')
    return json.loads(STATE.read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def payload_fingerprint(path):
    return {str(p.relative_to(path)): digest(p) for p in sorted(path.rglob('*')) if p.is_file()}

def signature(path):
    run('codesign', '--verify', '--strict', path)
    result = subprocess.run(['codesign', '-d', '--verbose=4', str(path)], capture_output=True, text=True)
    text = result.stdout + result.stderr
    if result.returncode or 'Authority=Developer ID Application:' not in text or '(runtime)' not in text or 'Timestamp=' not in text:
        raise RuntimeError(f'{path.name}: Developer ID Application, hardened runtime and secure timestamp are all required.')
    team = re.search(r'^TeamIdentifier=(\S+)$', text, re.M)
    if not team:
        raise RuntimeError('Missing signing team identifier.')
    return team.group(1)

def prepare(identity):
    if STATE.exists():
        raise RuntimeError('A preparation/submission already exists. Use status/finish; do not overwrite an active submission.')
    identities = run('security', 'find-identity', '-v', '-p', 'codesigning')
    available = re.findall(r'\b([A-F0-9]{40}) "(Developer ID Application:[^"]+)"', identities)
    matches = [pair for pair in available if not identity or identity in pair]
    if len(matches) != 1:
        raise RuntimeError('A unique Developer ID Application identity with its private key is required. Apple Development is insufficient. Select one with --identity if multiple exist.')
    identity_hash, identity_name = matches[0]
    if not (ROOT/'Prisma.app/Contents/MacOS/Prisma').is_file() or not (ROOT/PLUGIN/'plugin').is_file():
        raise RuntimeError('Run build.command before preparing a release.')
    WORK.mkdir(parents=True, exist_ok=True)
    payload = WORK/'payload'
    if payload.exists():
        raise RuntimeError('Unfinished payload exists. Inspect it before explicitly removing/re-preparing it.')
    shutil.copytree(ROOT/'Prisma.app', payload/'Prisma.app')
    shutil.copytree(ROOT/PLUGIN, payload/PLUGIN)
    shutil.copy2(ROOT/'LICENSE', payload/PLUGIN/'LICENSE')
    app = payload/'Prisma.app'
    helper = app/'Contents/MacOS/PrismaChromeHost'
    plugin = payload/PLUGIN/'plugin'
    base = ['codesign', '--force', '--options', 'runtime', '--timestamp', '--sign', identity_hash]
    run(*base, '--identifier', 'local.prisma.chrome', helper)
    run(*base, '--identifier', 'io.github.kory-.prisma', plugin)
    run(*base, '--entitlements', ROOT/'Release/Prisma.entitlements', app)
    teams = {signature(path) for path in [app, helper, plugin]}
    if len(teams) != 1:
        raise RuntimeError('App, native helper and plugin must have the same signing team.')
    archive = WORK/'submission.zip'
    run('ditto', '-c', '-k', '--keepParent', payload, archive)
    version = plistlib.loads((app/'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
    state = {'phase':'prepared', 'version':version, 'team':teams.pop(), 'identity':identity_name,
             'archive_sha256':digest(archive), 'payload':payload_fingerprint(payload)}
    write_state(state)
    print(f'Prepared Developer ID-signed Prisma {version} and Stream Deck executable.')

def authentication(profile):
    if not profile:
        raise RuntimeError('Set PRISMA_NOTARY_PROFILE or pass --profile for your notarytool Keychain profile.')
    return ['--keychain-profile', profile, '--output-format', 'json']

def submit(profile):
    state = read_state()
    if state['phase'] != 'prepared' or state.get('submission_id'):
        raise RuntimeError('Submission was already attempted. Resume with status; inspect notarytool history if its ID was not returned.')
    archive = WORK/'submission.zip'
    if digest(archive) != state['archive_sha256'] or payload_fingerprint(WORK/'payload') != state['payload']:
        raise RuntimeError('Prepared payload changed. Refusing to submit a different artifact.')
    auth = authentication(profile)
    # Record before network I/O, so an interruption never causes an automatic duplicate upload.
    state['phase'] = 'submission-attempted'
    write_state(state)
    response = json.loads(run('xcrun', 'notarytool', 'submit', archive, *auth, '--no-wait'))
    state['submission_id'] = response['id']
    state['phase'] = 'submitted'
    state['last_response'] = response
    write_state(state)
    print(json.dumps(response, indent=2))

def status(profile):
    state = read_state()
    if not state.get('submission_id'):
        raise RuntimeError('No confirmed submission ID. Do not re-submit; inspect history after an interrupted upload.')
    response = json.loads(run('xcrun', 'notarytool', 'info', state['submission_id'], *authentication(profile)))
    if response.get('id') != state['submission_id']:
        raise RuntimeError('Notary response does not identify this submission.')
    state['last_response'] = response
    state['phase'] = response.get('status', 'unknown')
    write_state(state)
    print(json.dumps(response, indent=2))
    return state

def finish(profile, cli):
    state = status(profile)
    if state['last_response'].get('status') != 'Accepted':
        raise RuntimeError('Apple has not accepted this submission. No notarized release will be produced.')
    payload = WORK/'payload'
    # Keep the submitted payload untouched; stapling happens in a separate distribution copy.
    if payload_fingerprint(payload) != state['payload']:
        raise RuntimeError('The signed payload no longer matches the submitted files.')
    destination = WORK/'distribution'
    app = destination/'Prisma.app'
    if destination.exists():
        shutil.rmtree(destination)  # Generated staging only; no submission or credentials live here.
    shutil.copytree(payload/'Prisma.app', app)
    plugin = destination/PLUGIN
    shutil.copytree(payload/PLUGIN, plugin)
    run('xcrun', 'notarytool', 'log', state['submission_id'], *authentication(profile), WORK/'notary-log.json')
    log = json.loads((WORK/'notary-log.json').read_text())
    if log.get('status') != 'Accepted' or str(log.get('sha256', '')).lower() != state['archive_sha256']:
        raise RuntimeError('The Apple log must accept the exact uploaded archive.')
    run('xcrun', 'stapler', 'staple', app)
    run('xcrun', 'stapler', 'validate', app)
    signature(app)
    signature(app/'Contents/MacOS/PrismaChromeHost')
    signature(plugin/'plugin')
    run('spctl', '--assess', '--type', 'execute', '--verbose=2', app)
    output = ROOT/'dist/notarized'
    output.mkdir(parents=True, exist_ok=True)
    run(cli, 'validate', '--no-update-check', plugin)
    run(cli, 'pack', '--no-update-check', plugin, '--output', output, '--force')
    packed_plugin = output/'io.github.kory-.prisma.streamDeckPlugin'
    with zipfile.ZipFile(packed_plugin) as archive:
        names = [name for name in archive.namelist() if name.endswith('/plugin')]
        if len(names) != 1 or hashlib.sha256(archive.read(names[0])).hexdigest() != digest(payload/PLUGIN/'plugin'):
            raise RuntimeError('Packaged plugin differs from the notarized executable.')
    run('python3', ROOT/'Source/MakeProfile.py', '--manifest', plugin/'manifest.json')
    run('python3', ROOT/'Source/PackageRelease.py', '--app', app, '--output-dir', output)
    # Verify the shipped ZIP, not only the pre-packaging bundle.
    with tempfile.TemporaryDirectory(prefix='verify-', dir=WORK) as temporary:
        run('ditto', '-x', '-k', output/f'Prisma-{state["version"]}-macOS-arm64.zip', temporary)
        extracted = Path(temporary)/'Prisma.app'
        signature(extracted)
        run('xcrun', 'stapler', 'validate', extracted)
        run('spctl', '--assess', '--type', 'execute', '--verbose=2', extracted)
    state['phase'] = 'verified'
    write_state(state)
    print(f'Apple accepted {state["submission_id"]}; stapled, Gatekeeper-verified artifacts: {output}')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['prepare','submit','status','finish'])
    parser.add_argument('--identity', default=os.environ.get('PRISMA_SIGN_IDENTITY'))
    parser.add_argument('--profile', default=os.environ.get('PRISMA_NOTARY_PROFILE'))
    parser.add_argument('--streamdeck-cli', default=os.environ.get('STREAMDECK_CLI') or shutil.which('streamdeck'))
    args = parser.parse_args()
    try:
        if args.command == 'prepare': prepare(args.identity)
        elif args.command == 'submit': submit(args.profile)
        elif args.command == 'status': status(args.profile)
        else:
            if not args.streamdeck_cli: raise RuntimeError('Set STREAMDECK_CLI before finishing.')
            finish(args.profile, args.streamdeck_cli)
    except (RuntimeError, KeyError, json.JSONDecodeError) as error:
        parser.exit(1, f'{error}\n')

if __name__ == '__main__':
    main()
