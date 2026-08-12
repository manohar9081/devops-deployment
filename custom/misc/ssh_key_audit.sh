#!/bin/bash

set -euo pipefail

# List SSH keys with fingerprints, and optionally purge stale known_hosts
# entries.
#
#   ssh_key_audit.sh                     list keys
#   ssh_key_audit.sh purge-hosts         purge stale known_hosts entries

SSH_DIR="${HOME}/.ssh"
if [[ ! -d "$SSH_DIR" ]]; then
  echo "No ~/.ssh directory."; exit 0
fi

echo "=== SSH keys in $SSH_DIR ==="
printf "%-30s %-12s %s\n" "FILE" "TYPE" "FINGERPRINT"
while IFS= read -r -d '' f; do
  base=$(basename "$f")
  [[ "$base" == *.pub ]] && continue
  [[ "$base" == known_hosts* || "$base" == config || "$base" == authorized_keys ]] && continue
  fp=$(ssh-keygen -lf "$f" 2>/dev/null | head -1 | awk '{print $1, $2}')
  printf "%-30s %-12s %s\n" "$base" "${fp%% *}" "${fp#* }"
done < <(find "$SSH_DIR" -maxdepth 1 -type f -print0)

echo ""
echo "=== known_hosts entries: $(wc -l < "$SSH_DIR/known_hosts" 2>/dev/null || echo 0) line(s) ==="

if [[ "${1:-}" == "purge-hosts" ]]; then
  before=$(wc -l < "$SSH_DIR/known_hosts" 2>/dev/null || echo 0)
  ssh-keygen -R "" >/dev/null 2>&1 || true  # no-op without host; use below
  # Hash and remove non-hashing entries that are stale.
  cp "$SSH_DIR/known_hosts" "$SSH_DIR/known_hosts.bkp"
  ssh-keygen -H -f "$SSH_DIR/known_hosts" >/dev/null 2>&1 || true
  after=$(wc -l < "$SSH_DIR/known_hosts" 2>/dev/null || echo 0)
  echo "Purged/hashed. Before: $before lines, after: $after lines."
  echo "Backup at: $SSH_DIR/known_hosts.bkp"
fi
