#!/bin/bash

set -euo pipefail

# Source shell configuration for AWS SSO
if [[ -f "$HOME/.bash_function" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.bash_function"
else
  echo "No suitable shell configuration file found for sourcing. Exiting..."
  exit 1
fi

if command -v sso_profile >/dev/null 2>&1; then
  sso_profile
else
  echo "sso_profile function is not available. Exiting..."
  exit 1
fi

if ! aws s3 ls >/dev/null 2>&1; then
  echo "AWS CLI is not configured properly or credentials are missing."
  exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf is not installed. Please install it and try again."
  exit 1
fi

AWS_PROFILE="${AWS_PROFILE:-default}"

update_object_list() {
  local bucket="$1"
  local outfile="$2"

  echo "Fetching updated object list for bucket: $bucket in the background..."
  local temp_file
  temp_file=$(mktemp)

  aws s3api list-objects-v2 \
    --bucket "$bucket" \
    --query "Contents[].Key" \
    --output text | tr '\t' '\n' >"$temp_file"

  # Add common prefixes (folders) explicitly to the list
  awk -F'/' '{if (NF > 1) {print $1"/"}}' "$temp_file" | sort -u >>"$temp_file"

  sort -u "$temp_file" >"$outfile"

  rm -f "$temp_file"
  echo "Object list updated: $outfile"
}

LOG_DIR="$HOME/.local/bin/s3-bucket-objects/$AWS_PROFILE"
mkdir -p "$LOG_DIR"

echo "Fetching S3 buckets list..."
BUCKETS=$(aws s3 ls | awk '{print $3}')

if [[ -z "$BUCKETS" ]]; then
  echo "No buckets found."
  exit 1
fi

SOURCE_BUCKET=$(echo "$BUCKETS" | fzf --height 40% --reverse --prompt="Select source bucket:" --exact)

if [[ -z "$SOURCE_BUCKET" ]]; then
  echo "No source bucket selected. Exiting..."
  exit 1
fi

OBJECTS_FILE="$LOG_DIR/${SOURCE_BUCKET}.txt"

# Kick off the refresh in the background and capture the PID so we can wait on it.
update_object_list "$SOURCE_BUCKET" "$OBJECTS_FILE" &
FETCH_PID=$!

echo "Waiting for object list file to be created or updated..."

# Wait until the background job completes (or errors out). With set -e we cannot
# blindly `wait`; instead poll for the process to finish writing the file.
wait "$FETCH_PID" || {
  echo "Failed to fetch object list. Exiting..."
  exit 1
}

if [[ ! -s "$OBJECTS_FILE" ]]; then
  echo "Object list is empty or not yet fetched. Exiting..."
  exit 1
fi

SELECTED=$(fzf --height 40% --reverse \
  --prompt="Select files/folders to download (TAB to mark, ENTER to confirm): " \
  --multi \
  --exact \
  --bind "ctrl-a:select-all,ctrl-d:deselect-all,ctrl-r:reload(cat \"$OBJECTS_FILE\")" \
  <"$OBJECTS_FILE" || true)

if [[ -z "$SELECTED" ]]; then
  echo "No selection made or fzf exited. Exiting..."
  exit 1
fi

read -r -p "Enter destination directory to download files or folders: " LOCAL_DEST

if [[ -z "$LOCAL_DEST" || "$LOCAL_DEST" == "/" || "$LOCAL_DEST" == "~" ]]; then
  echo "Invalid destination directory. Exiting..."
  exit 1
fi

mkdir -p "$LOCAL_DEST"

ok=0
fail=0
while IFS= read -r ITEM; do
  [[ -z "$ITEM" ]] && continue
  if [[ "$ITEM" == */ ]]; then
    echo "Copying folder $ITEM..."
    if aws s3 cp "s3://$SOURCE_BUCKET/$ITEM" "$LOCAL_DEST/$ITEM" --recursive; then
      ((ok++))
    else
      echo "  Failed: $ITEM"
      ((fail++))
    fi
  else
    echo "Copying file $ITEM..."
    mkdir -p "$(dirname "$LOCAL_DEST/$ITEM")"
    if aws s3 cp "s3://$SOURCE_BUCKET/$ITEM" "$LOCAL_DEST/$ITEM"; then
      ((ok++))
    else
      echo "  Failed: $ITEM"
      ((fail++))
    fi
  fi
done <<<"$SELECTED"

echo ""
echo "Download complete. Success: $ok, Failed: $fail -> $LOCAL_DEST"
