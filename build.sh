#!/bin/bash
set -euo pipefail

swift build 2>&1
cp .build/debug/KalshiQuickSearchApp dist/TruthPulse.app/Contents/MacOS/TruthPulse
echo "✓ dist/TruthPulse.app updated"
