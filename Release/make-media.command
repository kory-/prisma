#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
xcrun clang++ -std=c++17 -fobjc-arc -framework Cocoa Release/MakeMarketplaceMedia.mm -o .build/make-marketplace-media
.build/make-marketplace-media Release/Marketplace
