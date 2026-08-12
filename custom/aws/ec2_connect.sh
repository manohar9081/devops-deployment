#!/bin/bash

set -euo pipefail

# Browse EC2 instances (Name, state, IP) via fzf and start an SSM session on
# the chosen one. Replaces the need to hardcode per-host aliases.

if [[ -f "$HOME/.bash_function" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.bash_function"
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is not installed. Exiting..."; exit 1
fi
if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf is not installed. Exiting..."; exit 1
fi

AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Get all running instances, flatten tags to "Name | State | PrivIP | PubIP"
echo "Fetching instances for profile '$AWS_PROFILE' / region '$AWS_REGION'..."
MAP=$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]" \
  --output text | awk -F'\t' '{
    name=$5==""?"(unnamed)":$5
    printf "%s | %s | %s | %s | %s\n", name, $2, $3, $4==""?"-":$4, $1
  }')

if [[ -z "$MAP" ]]; then
  echo "No running instances found."; exit 0
fi

SELECTION=$(echo "$MAP" | fzf --height 40% --reverse \
  --header="Name | State | PrivIP | PubIP | Id" \
  --prompt="Select instance: " --exact || true)
[[ -z "$SELECTION" ]] && { echo "No selection. Exiting..."; exit 0; }

INSTANCE_ID=$(echo "$SELECTION" | awk -F'|' '{gsub(/ /,"",$5); print $5}')
echo "Connecting via SSM to $INSTANCE_ID ..."
if command -v session-manager-plugin >/dev/null 2>&1; then
  aws ssm start-session --target "$INSTANCE_ID" \
    --region "$AWS_REGION" --document-name "SSM-SessionManagerRunShell"
else
  echo "session-manager-plugin not installed. Run install-aws.sh first."
  exit 1
fi
