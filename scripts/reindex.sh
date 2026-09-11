#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
IP=$(terraform -chdir="$ROOT/infrastructure/terraform" output -raw public_ip)
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$IP" 'FORCE_REINDEX=1 /srv/devops-runbooks/app/bootstrap-index.sh'
