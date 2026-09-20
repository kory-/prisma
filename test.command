#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/logic-test
for test in AudioTests SlotTests PreferencesTests BrowserTabsTests; do
  xcrun clang++ -std=c++17 -fobjc-arc -fsanitize=address,undefined -g -framework Cocoa -framework CoreAudio -framework ServiceManagement "Tests/$test.mm" -o ".build/$test"
  ".build/$test"
done
cp Tests/StreamDeckLogicTests.swift .build/logic-test/main.swift
mkdir -p .build/swift-test-cache
prisma_cache="$(cd .build/swift-test-cache && pwd -P)"
xcrun swiftc -swift-version 5 -D TESTING -module-cache-path "$prisma_cache" Source/StreamDeck.swift .build/logic-test/main.swift -o .build/StreamDeckTests
.build/StreamDeckTests

node Tests/ChromeAudioTests.mjs

node Tests/ChromeWorkerTests.mjs

node Tests/LocalizationWebTests.mjs
python3 Tests/LocalizationAudit.py

python3 Tests/NotarizationTests.py
