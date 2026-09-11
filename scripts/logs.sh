#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
IP=$(terraform -chdir="$ROOT/infrastructure/terraform" output -raw public_ip)
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$IP" 'journalctl -f -u devops-runbooks-llm -u devops-runbooks-rag -u devops-runbooks-web -u nginx'
