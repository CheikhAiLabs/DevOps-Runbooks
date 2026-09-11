#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TF="$ROOT/infrastructure/terraform"
ANSIBLE="$ROOT/infrastructure/ansible"

SSH_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=5
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)

phase() {
  echo
  printf '\033[1;32m==> [%s/7] %s\033[0m\n' "$1" "$2"
}

resolve_project_id() {

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
    echo
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

    echo "Scaleway Project ID saved locally in:"
    echo "  $TF/terraform.tfvars"
  fi

  export TF_VAR_project_id="$SCW_PROJECT_ID"
}

"$ROOT/scripts/bootstrap-local.sh"

resolve_project_id

CLIENT_IP=${CLIENT_IP:-$(curl -4 -fsS https://api.ipify.org)}
CLIENT_CIDR="${CLIENT_IP}/32"

export TF_VAR_ssh_allowed_cidr="$CLIENT_CIDR"

###############################################################################
# PHASE 1
###############################################################################

phase 1 "Terraform infrastructure"

terraform -chdir="$TF" init
terraform -chdir="$TF" apply -auto-approve

PUBLIC_IP=$(terraform -chdir="$TF" output -raw public_ip)
SERVER_ID=$(terraform -chdir="$TF" output -raw server_id)

SERVER_UUID="${SERVER_ID##*/}"

FQDN="${SERVER_UUID}.pub.instances.scw.cloud"

###############################################################################
# PHASE 2
###############################################################################

phase 2 "Scaleway public DNS and SSH readiness"

echo "Public IP : $PUBLIC_IP"
echo "Server ID : $SERVER_ID"
echo "FQDN      : $FQDN"
echo "Client IP : $CLIENT_IP"

echo
echo "Waiting for Scaleway public DNS..."

python3 - "$FQDN" "$PUBLIC_IP" <<'PYDNS'
import socket
import sys
import time

name, expected = sys.argv[1:]

for attempt in range(1, 61):

    try:
        ips = {
            item[4][0]
            for item in socket.getaddrinfo(
                name,
                443,
                family=socket.AF_INET,
            )
        }

        if expected in ips:
            print(
                f"DNS ready: {name} -> {expected}"
            )
            break

    except OSError:
        pass

    print(
        f"DNS waiting: {attempt}/60",
        flush=True,
    )

    time.sleep(2)

else:
    raise SystemExit(
        f"Scaleway FQDN {name} did not resolve to {expected}"
    )
PYDNS


echo
echo "Waiting for SSH..."

for i in $(seq 1 90); do

  if ssh \
    "${SSH_OPTS[@]}" \
    root@"$PUBLIC_IP" \
    true \
    >/dev/null 2>&1
  then
    echo "SSH ready"
    break
  fi

  printf "SSH waiting: %s/90\r" "$i"

  if [ "$i" = 90 ]; then
    echo
    echo "SSH timeout"
    exit 1
  fi

  sleep 5
done

echo

###############################################################################
# PHASE 3
###############################################################################

phase 3 "Ansible full-stack configuration"

ssh \
  "${SSH_OPTS[@]}" \
  root@"$PUBLIC_IP" \
  ': > /tmp/devops-runbooks-progress.log' \
  >/dev/null 2>&1 || true


cd "$ANSIBLE"

ANSIBLE_CONFIG="$ANSIBLE/ansible.cfg" \
"$ROOT/.deploy-venv/bin/ansible-playbook" \
  -i "$PUBLIC_IP," \
  -u root \
  playbook.yml \
  -e "public_ip=$PUBLIC_IP client_ip=$CLIENT_IP fqdn=$FQDN" &

ANSIBLE_PID=$!

last_line=""

while kill -0 "$ANSIBLE_PID" >/dev/null 2>&1; do

  line=$(
    ssh \
      "${SSH_OPTS[@]}" \
      root@"$PUBLIC_IP" \
      'tail -n 1 /tmp/devops-runbooks-progress.log 2>/dev/null || true' \
      2>/dev/null || true
  )

  if [ -n "$line" ] && [ "$line" != "$last_line" ]; then
    printf '\033[0;36m   progress: %s\033[0m\n' "$line"
    last_line="$line"
  fi

  sleep 5
done

wait "$ANSIBLE_PID"

###############################################################################
# PHASE 4
###############################################################################

phase 4 "Application health"

cd "$ROOT"

RUNBOOK_FQDN="$FQDN" \
"$ROOT/scripts/verify.sh"

###############################################################################
# PHASE 5
###############################################################################

phase 5 "Deployment summary"

echo "Infrastructure : ready"
echo "Scaleway DNS   : ready"
echo "Qdrant         : ready"
echo "Embedding      : ready"
echo "Reranker       : ready"
echo "LLM            : ready"
echo "RAG API        : ready"
echo "Web UI         : ready"
echo "OCR            : ready"
echo "HTTPS          : ready"

###############################################################################
# PHASE 6
###############################################################################

phase 6 "Access"

echo
echo "https://$FQDN"

###############################################################################
# PHASE 7
###############################################################################

phase 7 "Complete"

echo
echo "Runbook AI deployment completed successfully."
echo
echo "URL:"
echo "https://$FQDN"
