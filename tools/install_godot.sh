#!/usr/bin/env bash
# Installs the pinned Godot version used by MONSERA (Linux x86_64) to ~/.local/bin/godot.
# Idempotent: does nothing if the right version is already on PATH.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
INSTALL_DIR="${GODOT_INSTALL_DIR:-$HOME/.local/bin}"
BIN="$INSTALL_DIR/godot"

if command -v godot >/dev/null 2>&1 && godot --version 2>/dev/null | grep -q "^${GODOT_VERSION}.stable"; then
  echo "Godot ${GODOT_VERSION} already installed: $(command -v godot)"
  exit 0
fi

mkdir -p "$INSTALL_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
echo "Downloading $URL"
curl -fsSL -o "$TMP/godot.zip" "$URL"
unzip -q "$TMP/godot.zip" -d "$TMP"
mv "$TMP/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$BIN"
chmod +x "$BIN"
echo "Installed: $("$BIN" --version) -> $BIN"
case ":$PATH:" in *":$INSTALL_DIR:"*) ;; *) echo "Add $INSTALL_DIR to PATH." ;; esac
