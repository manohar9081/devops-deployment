#!/bin/bash

set -euo pipefail

LOCAL_BIN="$HOME/.local/bin"
SCRIPT_DIR="$HOME/devops-deployment/scripts"
SCRIPT_TMPDIR="$HOME/devops-deployment/tmp"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

mkdir -p "$SCRIPT_TMPDIR" "$SCRIPT_DIR"

if [[ "$OS" != "linux" ]]; then
  echo "Unsupported OS: this installer only handles Linux (got '$OS')."
  exit 1
fi

if [[ "$ARCH" == "x86_64" ]]; then
  ARCH="x86_64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH="aarch64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Session Manager plugin (SSM). Bundled as an .rpm for both linux arches.
if ! command -v session-manager-plugin >/dev/null 2>&1; then
  case "$ARCH" in
    x86_64) SSM_PKG="linux_64bit" ;;
    aarch64) SSM_PKG="linux_arm64" ;;
  esac
  curl --fail -L -o "$SCRIPT_TMPDIR/session-manager-plugin.rpm" \
    "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/${SSM_PKG}/session-manager-plugin.rpm"
  rpm2cpio "$SCRIPT_TMPDIR/session-manager-plugin.rpm" | cpio -D "$SCRIPT_TMPDIR" -idm --quiet
  mv "$SCRIPT_TMPDIR/usr/local/sessionmanagerplugin/bin/session-manager-plugin" "$LOCAL_BIN/"
fi

# AWS CLI v2. Official installer ships one bundle per arch.
curl --fail -L -o "$SCRIPT_TMPDIR/awscliv2.zip" \
  "https://awscli.amazonaws.com/awscli-exe-${OS}-${ARCH}.zip"
unzip -q "$SCRIPT_TMPDIR/awscliv2.zip" -d "$SCRIPT_TMPDIR"
"$SCRIPT_TMPDIR/aws/install" -i "$LOCAL_BIN/aws-cli" -b "$LOCAL_BIN" --update

rm -rf "${SCRIPT_TMPDIR:?}/"*
echo "AWS and SSM are now installed..."
