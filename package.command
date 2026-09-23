#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
prisma_cli="${STREAMDECK_CLI:-$(command -v streamdeck || true)}"
if [[ -z "$prisma_cli" || ! -x "$prisma_cli" ]]; then
  echo 'Install @elgato/cli or set STREAMDECK_CLI to its executable.' >&2
  exit 1
fi
[[ -f LICENSE ]] || { echo 'A release requires a LICENSE file.' >&2; exit 1; }
codesign --verify --deep --strict Prisma.app
codesign --verify --strict io.github.kory-.prisma.sdPlugin/plugin
cp LICENSE io.github.kory-.prisma.sdPlugin/LICENSE
python3 Source/MakeProfile.py
mkdir -p dist
"$prisma_cli" validate --no-update-check io.github.kory-.prisma.sdPlugin
"$prisma_cli" pack --no-update-check io.github.kory-.prisma.sdPlugin --output dist --force
python3 Source/PluginPackagePermissions.py dist/io.github.kory-.prisma.streamDeckPlugin io.github.kory-.prisma.sdPlugin
python3 Source/PackageRelease.py
