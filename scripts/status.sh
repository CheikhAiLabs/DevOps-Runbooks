#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
IP=$(terraform -chdir="$ROOT/infrastructure/terraform" output -raw public_ip 2>/dev/null || true)
[ -n "$IP" ] || { echo "Infrastructure not deployed"; exit 1; }
SERVER_ID=$(terraform -chdir="$ROOT/infrastructure/terraform" output -raw server_id)
echo "URL: https://${SERVER_ID##*/}.pub.instances.scw.cloud"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$IP" 'systemctl --no-pager --full status devops-runbooks-llm devops-runbooks-rag devops-runbooks-web nginx | grep -E "^(●| +Active:)"; echo; free -h; df -h /srv/devops-runbooks'
