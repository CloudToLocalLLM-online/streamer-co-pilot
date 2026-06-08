#!/bin/bash
# Build Streamer Co-Pilot AppImage
# Usage: ./build-appimage.sh [--ci]
# In CI: relies on pre-downloaded linuxdeploy/appimagetool, or auto-downloads
set -euo pipefail

CI="${1:-}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/linux/x64/release/bundle"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp}"
ICON="${REPO_ROOT}/packaging/appimage/streamer-co-pilot.png"
DESKTOP="${REPO_ROOT}/packaging/appimage/streamer-co-pilot.desktop"
METADATA="${REPO_ROOT}/packaging/flatpak/com.streamer-co-pilot.app.metainfo.xml"

if [ ! -d "$BUILD_DIR" ]; then
  echo "No Linux build found. Run 'flutter build linux --release' first."
  exit 1
fi

# Prepare AppDir
APPDIR="$(mktemp -d)"
trap 'rm -rf "$APPDIR"' EXIT

cp -r "$BUILD_DIR"/* "$APPDIR/"
mkdir -p "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps" "$APPDIR/usr/share/metainfo"

# Generate icon if missing
if [ ! -f "$ICON" ]; then
  mkdir -p "$(dirname "$ICON")"
  python3 -c "
from PIL import Image, ImageDraw
img = Image.new('RGBA', (256, 256), (124, 58, 237, 255))
d = ImageDraw.Draw(img)
d.rounded_rectangle([20, 20, 236, 236], radius=30, fill=(139, 92, 246, 255))
img.save('$ICON')
" 2>/dev/null || convert -size 256x256 xc:'#7c3aed' -gravity center \
    -pointsize 28 -fill white -annotate 0 "SCP" "$ICON" 2>/dev/null || {
    echo "Cannot generate icon (no PIL or ImageMagick). Skipping icon."
    touch "$ICON"
  }
fi

cp "$ICON" "$APPDIR/streamer-co-pilot.png"
cp "$ICON" "$APPDIR/usr/share/icons/hicolor/256x256/apps/streamer-co-pilot.png"

# Desktop entry
cp "$DESKTOP" "$APPDIR/streamer-co-pilot.desktop"
cp "$DESKTOP" "$APPDIR/usr/share/applications/streamer-co-pilot.desktop"

# AppStream metadata
if [ -f "$METADATA" ]; then
  cp "$METADATA" "$APPDIR/usr/share/metainfo/streamer-co-pilot.appdata.xml"
fi

# AppRun — resolves bundle data/lib relative to AppDir root
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/streamer_co_pilot" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# Download appimagetool if not cached
APPIMAGETOOL="${APPIMAGETOOL:-}"
if [ -z "$APPIMAGETOOL" ] || [ ! -f "$APPIMAGETOOL" ]; then
  APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  APPIMAGETOOL="/tmp/appimagetool-x86_64.AppImage"
  if [ ! -f "$APPIMAGETOOL" ]; then
    curl -sLo "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
    chmod +x "$APPIMAGETOOL"
  fi
fi

"$APPIMAGETOOL" "$APPDIR" "${OUTPUT_DIR}/streamer-co-pilot-x86_64.AppImage"
echo "AppImage built: ${OUTPUT_DIR}/streamer-co-pilot-x86_64.AppImage"
