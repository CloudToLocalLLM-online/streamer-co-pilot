#!/bin/bash
# Streamer Co-Pilot — Linux install script
# Usage: curl -fsSL https://github.com/imrightguy/streamer-co-pilot/releases/latest/download/install.sh | bash

set -euo pipefail

INSTALL_VERSION="${INSTALL_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/streamer-co-pilot}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
APPIMAGE_NAME="StreamerCoPilot-x86_64.AppImage"

echo "── Streamer Co-Pilot Installer ──"
echo ""

# Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" != "Linux" ]; then
  echo "✗ This installer is for Linux only."
  echo "  Windows: download the Setup.exe from GitHub Releases."
  exit 1
fi

if [ "$ARCH" != "x86_64" ]; then
  echo "✗ Only x86_64 is supported (detected: $ARCH)."
  exit 1
fi

# Resolve version
if [ "$INSTALL_VERSION" = "latest" ]; then
  echo "→ Resolving latest version..."
  DOWNLOAD_URL="https://github.com/imrightguy/streamer-co-pilot/releases/latest/download/$APPIMAGE_NAME"
else
  DOWNLOAD_URL="https://github.com/imrightguy/streamer-co-pilot/releases/download/v$INSTALL_VERSION/$APPIMAGE_NAME"
fi

# Create directories
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# Download AppImage
echo "→ Downloading Streamer Co-Pilot..."
TMP_FILE=$(mktemp)
if command -v curl &>/dev/null; then
  curl -fsSL -o "$TMP_FILE" "$DOWNLOAD_URL"
elif command -v wget &>/dev/null; then
  wget -q -O "$TMP_FILE" "$DOWNLOAD_URL"
else
  echo "✗ Need curl or wget to download."
  exit 1
fi

chmod +x "$TMP_FILE"
mv "$TMP_FILE" "$INSTALL_DIR/$APPIMAGE_NAME"

# Create symlink
ln -sf "$INSTALL_DIR/$APPIMAGE_NAME" "$BIN_DIR/streamer-co-pilot"

# Desktop integration
if command -v xdg-desktop-menu &>/dev/null; then
  DESKTOP_FILE="$INSTALL_DIR/streamer-co-pilot.desktop"
  cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Streamer Co-Pilot
Comment=AI-powered streaming assistant
Exec=$INSTALL_DIR/$APPIMAGE_NAME
Icon=streamer-co-pilot
Terminal=false
Type=Application
Categories=Utility;
EOF
  chmod +x "$DESKTOP_FILE"
  xdg-desktop-menu install "$DESKTOP_FILE" 2>/dev/null || true
fi

echo ""
echo "✓ Installed v$INSTALL_VERSION to $INSTALL_DIR"
echo "  Run: streamer-co-pilot"
echo ""
echo "  Or add to PATH if needed:"
echo "    export PATH=\"\$PATH:$BIN_DIR\""
