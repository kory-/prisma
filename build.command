#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ $(uname -m) != arm64 ]]; then
  echo 'Prisma currently supports Apple Silicon builds only.' >&2
  exit 1
fi
mkdir -p 'Prisma.app/Contents/MacOS' 'Prisma.app/Contents/Resources' .build
xcrun clang++ -std=c++17 -fobjc-arc -O2 -arch arm64 -mmacosx-version-min=14.4 -framework Cocoa -framework CoreAudio -framework ServiceManagement Source/Mixer.mm -o 'Prisma.app/Contents/MacOS/Prisma'
xcrun clang++ -std=c++17 -fobjc-arc -O2 -arch arm64 -mmacosx-version-min=14.4 -framework Cocoa Source/ChromeHost.mm -o 'Prisma.app/Contents/MacOS/PrismaChromeHost'
codesign --force --sign - 'Prisma.app/Contents/MacOS/PrismaChromeHost'
cp Source/Info.plist 'Prisma.app/Contents/Info.plist'
ditto Source/Resources 'Prisma.app/Contents/Resources'
xcrun clang++ -std=c++17 -fobjc-arc -framework Cocoa Source/MakeIcons.mm -o .build/make-icons
.build/make-icons .build/brand Assets/PrismaIconArtwork.png
python3 Source/PackIcon.py .build/brand 'Prisma.app/Contents/Resources/Prism.icns'
cp .build/brand/prism-1024.png 'Prisma.app/Contents/Resources/PrismaIcon.png'
cp .build/brand/prism-128.png io.github.kory-.prisma.sdPlugin/icon.png
for size in 16 32 128; do
 cp ".build/brand/prism-$size.png" "ChromeExtension/icons/$size.png"
done
ditto ChromeExtension 'Prisma.app/Contents/Resources/ChromeExtension'
codesign --force --sign - 'Prisma.app'
mkdir -p .build/swift-cache
mixer_cache="$(cd .build/swift-cache && pwd -P)"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-macosx14.4 -O -module-cache-path "$mixer_cache" Source/StreamDeck.swift -o io.github.kory-.prisma.sdPlugin/plugin
codesign --force --sign - io.github.kory-.prisma.sdPlugin/plugin
echo 'Build complete: Prisma.app + Stream Deck plugin'

python3 Source/MakeProfile.py
