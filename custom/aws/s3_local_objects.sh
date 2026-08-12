#!/bin/bash

set -euo pipefail

# Lists and refreshes the cached object list for a chosen S3 bucket.
# Output is written to ~/.local/bin/s3-bucket-objects/<profile>/<bucket>.txt
# and can be browsed with fzf or consumed by other scripts.

if [[ -f "$HOME/.bash_function" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.bash_function"
else
  echo "No shell configuration file found for sourcing. Exiting..."
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

  echo "Fetching updated object list for bucket: $bucket..."
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

update_object_list "$SOURCE_BUCKET" "$OBJECTS_FILE"

if [[ ! -s "$OBJECTS_FILE" ]]; then
  echo "Bucket is empty or object list is empty."
  exit 0
fi

OBJ_COUNT=$(wc -l <"$OBJECTS_FILE")
echo "Cached $OBJ_COUNT objects for bucket '$SOURCE_BUCKET' -> $OBJECTS_FILE"

echo "Opening fzf viewer (ESC to exit)..."
fzf --height 40% --reverse \
  --prompt="Browse objects in $SOURCE_BUCKET: " \
  --exact \
  <"$OBJECTS_FILE" || true

echo "Done."
