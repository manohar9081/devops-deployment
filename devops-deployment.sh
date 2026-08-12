#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$HOME/devops-deployment/scripts"
SCRIPT_TMPDIR="$HOME/devops-deployment/tmp"
LOCAL_BIN="$HOME/.local/bin"

# Tool name -> install script mapping (single source of truth).
declare -A TOOL_SCRIPTS=(
  [kubectl]="$SCRIPT_DIR/install-kubectl.sh"
  [k9s]="$SCRIPT_DIR/install-k9s.sh"
  [helm]="$SCRIPT_DIR/install-helm.sh"
  [terraform]="$SCRIPT_DIR/install-terraform.sh"
  [aws]="$SCRIPT_DIR/install-aws.sh"
  [brave]="$SCRIPT_DIR/install-brave.sh"
  [helium]="$SCRIPT_DIR/install-helium.sh"
  [bashtools]="$SCRIPT_DIR/install-bashtools.sh"
  [fzf-setup]="$SCRIPT_DIR/install-fzf-setup.sh"
)


# Ensure $LOCAL_BIN is on PATH.
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
  CONFIG_FILE=""
  if [[ -f "$HOME/.bashrc" ]]; then
    CONFIG_FILE="$HOME/.bashrc"
  elif [[ -f "$HOME/.zshrc" ]]; then
    CONFIG_FILE="$HOME/.zshrc"
  else
    echo "No compatible shell config file found."
    exit 1
  fi
  echo "$LOCAL_BIN is not in the PATH. Adding it..."
  echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >> "$CONFIG_FILE"
  source "$CONFIG_FILE"
  echo "$LOCAL_BIN has been added to the PATH."
else
  echo "$LOCAL_BIN is already in the PATH."
fi

mkdir -p "$SCRIPT_TMPDIR"

run_install() {
  local tool="$1"
  local script="${TOOL_SCRIPTS[$tool]}"
  if [[ -z "$script" || ! -f "$script" ]]; then
    echo "ERROR: install script for '$tool' not found ($script)."
    return 1
  fi
  echo ">>> Installing ${tool}..."
  bash "$script"
}

echo "Select an option:"
echo "  1  - Install Kubectl"
echo "  2  - Install K9S"
echo "  3  - Install Helm"
echo "  4  - Install Terraform"
echo "  5  - Install AWS"
echo "  6  - Install Brave Browser"
echo "  7  - Install Helium Browser"
echo "  8  - Install Bash tools"
echo "  9  - Setup fzf/cursor (opt-in)"
echo "  10 - Install all"
echo "  11 - Install all (except fzf/cursor, Brave and Helium Browser)"
echo ""

read -rp "Enter option: " OPTION

case "$OPTION" in
  1) run_install kubectl ;;
  2) run_install k9s ;;
  3) run_install helm ;;
  4) run_install terraform ;;
  5) run_install aws ;;
  6) run_install brave ;;
  7) run_install helium ;;
  8) run_install bashtools ;;
  9) run_install fzf-setup ;;
  10)
    for tool in kubectl k9s helm terraform aws brave helium bashtools; do
      run_install "$tool"
    done
    ;;
  11)
    for tool in kubectl k9s helm terraform aws bashtools; do
      run_install "$tool"
    done
    ;;
  *)
    echo "Invalid option: '${OPTION}'."
    exit 1
    ;;
esac

echo "Done. Please reopen all terminals."
