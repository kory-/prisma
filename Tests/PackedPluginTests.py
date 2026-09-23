"""Launch the packed executable outside the checkout, without repairing files."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
args = parser.parse_args()
archive = args.archive.resolve()
with zipfile.ZipFile(archive) as packed:
    assert packed.testzip() is None, 'Corrupt plugin archive'
    manifest_paths = [p for p in packed.namelist() if p.endswith('/manifest.json')]
    assert len(manifest_paths) == 1, 'Expected one plugin manifest'
    manifest = json.loads(packed.read(manifest_paths[0]))
    folder = manifest['UUID'] + '.sdPlugin'
    for name in packed.namelist():
        path = Path(name)
        assert not path.is_absolute() and '..' not in path.parts
        assert path.parts[0] == folder
with tempfile.TemporaryDirectory(prefix='prisma-packed-plugin-') as temporary:
    subprocess.run(['ditto', '-x', '-k', str(archive), temporary], check=True)
    plugin = Path(temporary) / folder
    executable = plugin / manifest.get('CodePathMac', manifest['CodePath'])
    assert os.access(executable, os.X_OK), 'Packed executable lost execute permissions'
    subprocess.run(['codesign', '--verify', '--strict', str(executable)], check=True)
    # No chmod, source-directory links, or development files are supplied.
    subprocess.run([sys.executable, str(root/'Tests/StreamDeckTests.py'), str(executable)],
                   cwd=temporary, check=True, timeout=30)
print('PASS: shipped archive extracts, verifies, launches and registers outside the checkout')
