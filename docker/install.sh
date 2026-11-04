#!/bin/bash
# install.sh — build claude-desktop-runtime image + install claude-docker launcher
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

[ -f "$SCRIPT_DIR/build-fedora.sh" ] || cp "$SCRIPT_DIR/../build-fedora.sh" "$SCRIPT_DIR/"

echo "Building claude-desktop-runtime image (first run ~3 min, downloads Claude + Electron)..."
docker build -t claude-desktop-runtime "$SCRIPT_DIR"

mkdir -p "$HOME/bin"
cp "$SCRIPT_DIR/claude-docker-launcher.sh" "$HOME/bin/claude-docker"
chmod +x "$HOME/bin/claude-docker"

echo "Installed. Launch with:  claude-docker"
echo "(PATH must include ~/bin; log out/in once if it was missing)"
