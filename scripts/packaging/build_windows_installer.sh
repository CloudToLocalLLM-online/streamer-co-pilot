#!/bin/bash
# Build Windows installer for Streamer Co-Pilot
# Usage: bash scripts/packaging/build_windows_installer.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "── Streamer Co-Pilot — Windows Installer Build ──"

# 1. Flutter release build
echo ""
echo "[1/3] Building Flutter release..."
cd "$PROJECT_ROOT"
flutter build windows --release
echo "  ✓ Built to build/windows/x64/runner/Release/"

# 2. Check Inno Setup
echo ""
echo "[2/3] Checking Inno Setup..."
ISCC=""
if command -v iscc.exe &>/dev/null; then
  ISCC="iscc.exe"
elif [ -f "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" ]; then
  ISCC="/c/Program Files (x86)/Inno Setup 6/ISCC.exe"
else
  echo "  ✗ ISCC.exe not found. Install Inno Setup 6 from https://jrsoftware.org/isdl.php"
  exit 1
fi
echo "  ✓ Inno Setup found"

# 3. Build installer
echo ""
echo "[3/3] Building installer..."
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)
mkdir -p "$PROJECT_ROOT/dist/windows"

"$ISCC" \
  "/DMyAppVersion=$VERSION" \
  "/DMyAppSourceDir=$(cygpath -w "$PROJECT_ROOT/build/windows/x64/runner/Release")" \
  "/DMyOutputDir=$(cygpath -w "$PROJECT_ROOT/dist/windows")" \
  "$(cygpath -w "$PROJECT_ROOT/windows/installer/StreamerCoPilot.iss")"

echo ""
echo "── Done! ──"
echo "Installer: dist/windows/StreamerCoPilot-Windows-x64-Setup.exe"
ls -lh "$PROJECT_ROOT/dist/windows/"*.exe 2>/dev/null || echo "(not found)"
