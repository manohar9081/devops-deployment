#!/bin/bash

set -euo pipefail

kcontext_folder="$HOME/k8sconfig"
SCRIPT_TMPDIR="$HOME/devops-deployment/tmp"
LOCAL_BIN="$HOME/.local/bin"
KCONF_VERSION="v2.0.0"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

mkdir -p "$kcontext_folder" "$SCRIPT_TMPDIR"

if ! command_exists kconf; then
  echo "kconf is not installed. Downloading..."
  # Install kconf if missing (defer the list call until after this so we don't
  # capture empty output on first run).
  curl --fail -L -o "$SCRIPT_TMPDIR/kconf.tar.gz" \
    "https://github.com/particledecay/kconf/releases/download/${KCONF_VERSION}/kconf-linux-x86_64-${KCONF_VERSION}.tar.gz"
  tar -vxf "$SCRIPT_TMPDIR/kconf.tar.gz" -C "$SCRIPT_TMPDIR"
  mv "$SCRIPT_TMPDIR/kconf" "$LOCAL_BIN/"
  chmod +x "$LOCAL_BIN/kconf"
else
  echo "kconf is already installed."
fi

remove_all_contexts() {
  echo "Removing all existing contexts..."
  # Parse defensively: strip the active-context marker (`*`) and surrounding
  # whitespace; skip blank lines. read -r preserves special chars.
  kconf list 2>/dev/null | while read -r raw; do
    local context
    context="${raw#\*}"          # remove leading '*' (active marker)
    context="${context#"${context%%[![:space:]]*}"}" # trim leading whitespace
    context="${context%"${context##*[![:space:]]}"}" # trim trailing whitespace
    [[ -z "$context" ]] && continue
    if kconf rm "$context" >/dev/null 2>&1; then
      echo "Removed context: $context"
    else
      echo "Failed to remove context: $context"
    fi
  done
}

remove_all_contexts

shopt -s nullglob
added=0
failed=0
for kcontext_file in "$kcontext_folder"/*.yaml; do
  if [[ -f "$kcontext_file" ]]; then
    filename=$(basename "$kcontext_file" .yaml)
    if kconf add "$kcontext_file" --context-name="$filename" >/dev/null 2>&1; then
      echo "Added $kcontext_file with context name $filename"
      ((added++))
    else
      echo "Failed to add $kcontext_file"
      ((failed++))
    fi
  fi
done
shopt -u nullglob

rm -rf "${SCRIPT_TMPDIR:?}/"*
echo "Done. Contexts added: $added, failed: $failed."
