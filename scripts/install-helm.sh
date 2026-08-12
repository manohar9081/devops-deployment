#!/bin/bash

set -euo pipefail

LOCAL_BIN="$HOME/.local/bin"
SCRIPT_DIR="$HOME/devops-deployment/scripts"
SCRIPT_TMPDIR="$HOME/devops-deployment/tmp"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

mkdir -p "$SCRIPT_TMPDIR" "$SCRIPT_DIR"

get_latest_version() {
  VERSION=$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name | sed 's/^v//')
}

get_last_5_versions() {
  VERSIONS=$(curl -fsSL https://api.github.com/repos/helm/helm/releases \
    | jq -r 'map(select(.prerelease == false)) | .[0:5] | .[].tag_name' \
    | sed 's/^v//')

  echo "The last 5 stable helm versions are:"
  echo "$VERSIONS"
}
get_last_5_versions

echo "Enter the helm version you want to download (press Enter for the latest version):"
read -r USER_VERSION

if [[ -z "$USER_VERSION" ]]; then
  echo "No version specified, fetching the latest stable version..."
  get_latest_version
else
  VERSION="$USER_VERSION"
  echo "Downloading helm version $VERSION..."
fi

if [[ "$ARCH" == "x86_64" ]]; then
  ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

DOWNLOAD_URL="https://get.helm.sh/helm-v$VERSION-$OS-$ARCH.tar.gz"
echo "Downloading helm from: $DOWNLOAD_URL"

curl --fail -L -o "$SCRIPT_TMPDIR/helm.tar.gz" "$DOWNLOAD_URL"

# Extract Helm
echo "Extracting helm..."
tar -xzf "$SCRIPT_TMPDIR/helm.tar.gz" -C "$SCRIPT_TMPDIR"
chmod +x "$SCRIPT_TMPDIR/$OS-$ARCH/helm"

echo "Helm version $VERSION has been downloaded"

cp "$SCRIPT_TMPDIR/$OS-$ARCH/helm" "$LOCAL_BIN/"

rm -rf "${SCRIPT_TMPDIR:?}/"*
echo "Helm is now installed..."
