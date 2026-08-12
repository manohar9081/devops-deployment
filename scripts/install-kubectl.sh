#!/bin/bash

set -euo pipefail

LOCAL_BIN="$HOME/.local/bin"
KUBECTL_VERSION_DOWNLOAD="$HOME/.local/bin/kubectl-versions"
SCRIPT_DIR="$HOME/devops-deployment/scripts"
SCRIPT_TMPDIR="$HOME/devops-deployment/tmp"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

mkdir -p "$SCRIPT_TMPDIR" "$SCRIPT_DIR" "$KUBECTL_VERSION_DOWNLOAD"

if [[ "$ARCH" == "x86_64" ]]; then
  ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

get_latest_version() {
  VERSION=$(curl -fsSL https://api.github.com/repos/kubernetes/kubernetes/releases/latest | jq -r .tag_name | sed 's/^v//')
}

get_last_5_versions() {
  VERSIONS=$(curl -fsSL https://api.github.com/repos/kubernetes/kubernetes/releases \
    | jq -r 'map(select(.prerelease == false)) | .[0:5] | .[].tag_name' \
    | sed 's/^v//')

  echo "The last 5 stable kubectl versions are:"
  echo "$VERSIONS"
}
get_last_5_versions

echo "Enter the kubectl version you want to download (press Enter for the latest version):"
read -r USER_VERSION

if [[ -z "$USER_VERSION" ]]; then
  echo "No version specified, fetching the latest stable version..."
  get_latest_version
else
  VERSION="$USER_VERSION"
  echo "Downloading kubectl version $VERSION..."
fi

DOWNLOAD_URL="https://dl.k8s.io/release/v$VERSION/bin/$OS/$ARCH/kubectl"
echo "Downloading kubectl from: $DOWNLOAD_URL"

curl --fail -L -o "$KUBECTL_VERSION_DOWNLOAD/kubectl-$VERSION" "$DOWNLOAD_URL"
chmod +x "$KUBECTL_VERSION_DOWNLOAD/kubectl-$VERSION"

ln -sf "$KUBECTL_VERSION_DOWNLOAD/kubectl-$VERSION" "$LOCAL_BIN/kubectl"
echo "kubectl version $VERSION has been downloaded to: $KUBECTL_VERSION_DOWNLOAD"

# Install kubens to $LOCAL_BIN
if ! command -v kubens >/dev/null 2>&1; then
  echo "Downloading kubens binary..."
  curl -fL "https://github.com/ahmetb/kubectx/releases/download/v0.9.5/kubens" -o "$SCRIPT_TMPDIR/kubens"
  chmod +x "$SCRIPT_TMPDIR/kubens"
  mv "$SCRIPT_TMPDIR/kubens" "$LOCAL_BIN/"
fi

# Install kubectx to $LOCAL_BIN
if ! command -v kubectx >/dev/null 2>&1; then
  echo "Downloading kubectx binary..."
  curl -fL "https://github.com/ahmetb/kubectx/releases/download/v0.9.5/kubectx" -o "$SCRIPT_TMPDIR/kubectx"
  chmod +x "$SCRIPT_TMPDIR/kubectx"
  mv "$SCRIPT_TMPDIR/kubectx" "$LOCAL_BIN/"
fi

rm -rf "${SCRIPT_TMPDIR:?}/"*
echo "Kubectl, Kubectx, Kubens are now installed..."
