#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
xcrun clang++ -std=c++17 -fobjc-arc -O2 -framework Cocoa -framework CoreAudio -framework ServiceManagement Tests/UIMemoryTests.mm -o .build/UIMemoryTests
.build/UIMemoryTests 20000 | tee .build/memory-test.log

python3 - <<'PYTEST'
from pathlib import Path
if 'PASS: reusable rows' not in Path('.build/memory-test.log').read_text():
    raise SystemExit('UI memory tests did not complete. Run in a logged-in macOS desktop session.')
PYTEST
