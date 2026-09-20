#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
exec python3 Source/Notarize.py "$@"
