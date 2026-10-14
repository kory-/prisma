"""Preserve executable permissions dropped by Stream Deck CLI 1.9.0's ZIP writer.

Run only on the local CLI output, before uploading it to Maker Console. Never
rewrite a DRM-processed download. File contents must match the source exactly.
"""
import argparse
from pathlib import Path
import stat
import tempfile
import zipfile


def preserve_permissions(archive, source):
    archive, source = Path(archive).resolve(), Path(source).resolve()
    with tempfile.TemporaryDirectory(dir=archive.parent) as temporary:
        output = Path(temporary) / archive.name
        with zipfile.ZipFile(archive) as original, zipfile.ZipFile(output, 'w') as packed:
            for entry in original.infolist():
                relative = Path(entry.filename)
                if relative.parts[0] != source.name or '..' in relative.parts or entry.is_dir():
                    raise ValueError(f'Unexpected archive entry: {entry.filename}')
                file = source.joinpath(*relative.parts[1:])
                data = original.read(entry)
                if file.is_symlink() or not file.is_file() or data != file.read_bytes():
                    raise ValueError(f'Archive differs from source: {entry.filename}')
                mode = 0o755 if file.stat().st_mode & stat.S_IXUSR else 0o644
                entry.create_system = 3
                entry.external_attr = (stat.S_IFREG | mode) << 16
                packed.writestr(entry, data)
        output.replace(archive)
    print('PASS: packed files preserve source executable permissions')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    preserve_permissions(args.archive, args.source)
