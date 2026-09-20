#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/language-previews
xcrun clang++ -std=c++17 -fobjc-arc -O2 -framework Cocoa -framework CoreAudio -framework ServiceManagement Tests/LocalizationTests.mm -o .build/LocalizationTests
.build/LocalizationTests Source/Resources .build/language-previews | tee .build/language-test.log
python3 - <<'PY'
from pathlib import Path
text = Path('.build/language-test.log').read_text()
if 'PASS: language negotiation' not in text:
    raise SystemExit('AppKit UI tests did not complete. Run this command in a logged-in macOS desktop session with WindowServer access.')
PY
node Tests/LocalizationWebTests.mjs
python3 Tests/LocalizationAudit.py
