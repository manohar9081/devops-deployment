#!/bin/bash

set -euo pipefail

# Helm release manager: fzf-pick a release across all namespaces, then
# status / history / rollback / uninstall / get-values.

if ! command -v helm >/dev/null 2>&1; then
  echo "helm is not installed. Exiting..."; exit 1
fi
if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf is not installed. Exiting..."; exit 1
fi

echo "Fetching helm releases across all namespaces..."
REL=$(helm list -A --output json \
  | jq -r '.[] | "\(.namespace) | \(.name) | \(.status) | \(.chart) | \(.app_version)"' \
  | fzf --height 40% --reverse \
        --header="Namespace | Release | Status | Chart | AppVersion" \
        --prompt="Select release: " --exact || true)
[[ -z "$REL" ]] && { echo "No release selected."; exit 0; }

NS=$(echo "$REL" | awk -F'|' '{gsub(/ /,"",$1); print $1}')
NAME=$(echo "$REL" | awk -F'|' '{gsub(/ /,"",$2); print $2}')

echo ""
echo "Release: $NAME  (namespace: $NS)"
echo "  1) status          2) history          3) get values"
echo "  4) rollback        5) uninstall        6) manifest"
read -r -p "Action [1]: " A
A="${A:-1}"

case "$A" in
  1) helm status "$NAME" -n "$NS" ;;
  2) helm history "$NAME" -n "$NS" ;;
  3) helm get values "$NAME" -n "$NS" ;;
  4)
    helm history "$NAME" -n "$NS"
    read -r -p "Revision to rollback to: " REV
    [[ -z "$REV" ]] && { echo "No revision."; exit 0; }
    helm rollback "$NAME" "$REV" -n "$NS"
    ;;
  5)
    read -r -p "Type 'yes' to uninstall $NAME: " CONF
    [[ "$CONF" == "yes" ]] && helm uninstall "$NAME" -n "$NS" || echo "Aborted."
    ;;
  6) helm get manifest "$NAME" -n "$NS" ;;
  *) echo "Invalid action."; exit 1 ;;
esac
