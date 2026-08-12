#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$HOME/devops-deployment/scripts"
SCRIPT_TMPDIR="$HOME/devops-deployment/tmp"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$SCRIPT_TMPDIR" "$SCRIPT_DIR"

ARCH="${1:-x86_64}"
VERSION=$(curl -fsSL https://api.github.com/repos/brave/brave-browser/releases/latest | jq -r .tag_name)

# Check and gracefully stop a running Brave process before replacing the binary.
# Try SIGTERM first (lets Brave save session/tabs), fall back to SIGKILL.
pid=$(pgrep -x brave || true)
if [[ -n "$pid" ]]; then
  echo "Brave is running (pid: $pid). Asking it to quit (SIGTERM)..."
  kill "$pid" 2>/dev/null || true
  for _ in {1..10}; do
    if ! pgrep -x brave >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  if pgrep -x brave >/dev/null 2>&1; then
    echo "Brave did not exit gracefully. Forcing (SIGKILL)..."
    pkill -9 -x brave || true
  fi
  echo "Brave stopped."
else
  echo "Brave is not running."
fi

# Download Brave Browser as AppImage
wget -O "$SCRIPT_TMPDIR/brave.AppImage" "https://github.com/srevinsaju/Brave-AppImage/releases/download/$VERSION/Brave-stable-${VERSION}-${ARCH}.AppImage"
cp -p "$SCRIPT_TMPDIR/brave.AppImage" "$LOCAL_BIN/"
chmod +x "$LOCAL_BIN/brave.AppImage"

rm -rf "${SCRIPT_TMPDIR:?}/"*
echo "Brave Browser is now installed..."
