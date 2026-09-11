#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TF="$ROOT/infrastructure/terraform"

CLIENT_IP=${CLIENT_IP:-$(curl -4 -fsS https://api.ipify.org)}

export TF_VAR_ssh_allowed_cidr="${CLIENT_IP}/32"

SCW_PROJECT_ID="${SCW_PROJECT_ID:-${TF_VAR_project_id:-}}"

if [ -z "$SCW_PROJECT_ID" ] && [ -f "$TF/terraform.tfvars" ]; then
  SCW_PROJECT_ID=$(
    awk -F'"' '
      /^[[:space:]]*project_id[[:space:]]*=/ {
        print $2
        exit
      }
    ' "$TF/terraform.tfvars"
  )
fi

if [ -z "$SCW_PROJECT_ID" ]; then
  read -r -p "Scaleway Project ID: " SCW_PROJECT_ID
fi

if [ -z "$SCW_PROJECT_ID" ]; then
  echo "ERROR: Scaleway Project ID is required."
  exit 1
fi

if [ ! -f "$TF/terraform.tfvars" ] || ! grep -qE '^[[:space:]]*project_id[[:space:]]*=' "$TF/terraform.tfvars"; then
  {
    echo
    echo "# Scaleway project selected during first deployment"
    printf 'project_id = "%s"\n' "$SCW_PROJECT_ID"
  } >> "$TF/terraform.tfvars"
fi

export TF_VAR_project_id="$SCW_PROJECT_ID"

terraform -chdir="$TF" init
terraform -chdir="$TF" destroy -auto-approve
