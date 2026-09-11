#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
"$ROOT/scripts/bootstrap-local.sh"
CLIENT_IP=${CLIENT_IP:-$(curl -4 -fsS https://api.ipify.org)}
export TF_VAR_ssh_allowed_cidr="${CLIENT_IP}/32"
TF="$ROOT/infrastructure/terraform"
SCW_PROJECT_ID="${SCW_PROJECT_ID:-${TF_VAR_project_id:-}}"
if [ -z "$SCW_PROJECT_ID" ] && [ -f "$TF/terraform.tfvars" ]; then
  SCW_PROJECT_ID=$(awk -F'"' '/^[[:space:]]*project_id[[:space:]]*=/ {print $2; exit}' "$TF/terraform.tfvars")
fi
if [ -z "$SCW_PROJECT_ID" ]; then
  read -r -p "Scaleway Project ID: " SCW_PROJECT_ID
fi
if [ -z "$SCW_PROJECT_ID" ]; then
  echo "ERROR: Scaleway Project ID is required."
  exit 1
fi
export TF_VAR_project_id="$SCW_PROJECT_ID"
terraform -chdir="$TF" init
terraform -chdir="$TF" apply -auto-approve
PUBLIC_IP=$(terraform -chdir="$TF" output -raw public_ip)
SERVER_ID=$(terraform -chdir="$TF" output -raw server_id)
FQDN="${SERVER_ID##*/}.pub.instances.scw.cloud"
cd "$ROOT/infrastructure/ansible"
ANSIBLE_CONFIG="$ROOT/infrastructure/ansible/ansible.cfg" "$ROOT/.deploy-venv/bin/ansible-playbook" -i "$PUBLIC_IP," -u root playbook.yml -e "public_ip=$PUBLIC_IP client_ip=$CLIENT_IP fqdn=$FQDN" --tags nginx
printf 'Access updated for %s\nURL: https://%s\n' "$CLIENT_IP" "$FQDN"
