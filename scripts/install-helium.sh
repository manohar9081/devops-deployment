#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$HOME/devops-deployment/scripts"
SCRIPT_TMPDIR="$HOME/devops-deployment/tmp"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$SCRIPT_TMPDIR" "$SCRIPT_DIR"

ARCH="${1:-x86_64}"
VERSION=$(curl -fsSL https://api.github.com/repos/imputnet/helium-linux/releases/latest | jq -r .tag_name)

# Check and gracefully stop a running Helium process before replacing the binary.
# Try SIGTERM first (lets Helium save session/tabs), fall back to SIGKILL.
pid=$(pgrep -x helium || true)
if [[ -n "$pid" ]]; then
  echo "Helium is running (pid: $pid). Asking it to quit (SIGTERM)..."
  kill "$pid" 2>/dev/null || true
  for _ in {1..10}; do
    if ! pgrep -x helium >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  if pgrep -x helium >/dev/null 2>&1; then
    echo "Helium did not exit gracefully. Forcing (SIGKILL)..."
    pkill -9 -x helium || true
  fi
  echo "Helium stopped."
else
  echo "Helium is not running."
fi

# Download Helium Browser as AppImage
wget -O "$SCRIPT_TMPDIR/helium.AppImage" "https://github.com/imputnet/helium-linux/releases/download/$VERSION/helium-${VERSION}-${ARCH}.AppImage"
cp -p "$SCRIPT_TMPDIR/helium.AppImage" "$LOCAL_BIN/"
chmod +x "$LOCAL_BIN/helium.AppImage"

rm -rf "${SCRIPT_TMPDIR:?}/"*
echo "Helium Browser is now installed..."
