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

echo "Fetching S3 buckets list..."
BUCKETS=$(aws s3 ls | awk '{print $3}')

if [[ -z "$BUCKETS" ]]; then
  echo "No buckets found."
  exit 1
fi

DEST_BUCKET=$(echo "$BUCKETS" | fzf --height 40% --reverse --prompt="Select destination bucket:" --exact || true)

if [[ -z "$DEST_BUCKET" ]]; then
  echo "No destination bucket selected. Exiting..."
  exit 1
fi

read -r -p "Enter the path to the file or folder to upload: " LOCAL_PATH

if [[ ! -e "$LOCAL_PATH" ]]; then
  echo "The specified file or folder does not exist. Exiting..."
  exit 1
fi

read -r -p "Enter the destination prefix in the bucket (or leave blank for root): " DEST_PREFIX

# Strip leading/trailing slashes so we never produce double slashes.
DEST_PREFIX="${DEST_PREFIX#/}"
DEST_PREFIX="${DEST_PREFIX%/}"

if [[ -d "$LOCAL_PATH" ]]; then
  if [[ -n "$DEST_PREFIX" ]]; then
    S3_URI="s3://$DEST_BUCKET/$DEST_PREFIX/"
  else
    S3_URI="s3://$DEST_BUCKET/"
  fi
  echo "Uploading folder $LOCAL_PATH to $S3_URI"
  aws s3 cp "$LOCAL_PATH" "$S3_URI" --recursive
elif [[ -f "$LOCAL_PATH" ]]; then
  FILE_NAME=$(basename "$LOCAL_PATH")
  if [[ -n "$DEST_PREFIX" ]]; then
    S3_URI="s3://$DEST_BUCKET/$DEST_PREFIX/$FILE_NAME"
  else
    S3_URI="s3://$DEST_BUCKET/$FILE_NAME"
  fi
  echo "Uploading file $LOCAL_PATH to $S3_URI"
  aws s3 cp "$LOCAL_PATH" "$S3_URI"
else
  echo "Invalid path provided. Exiting..."
  exit 1
fi

echo "Upload complete!"
