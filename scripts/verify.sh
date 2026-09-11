#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TF="$ROOT/infrastructure/terraform"

PUBLIC_IP=$(terraform -chdir="$TF" output -raw public_ip)
SERVER_ID=$(terraform -chdir="$TF" output -raw server_id)
FQDN="${RUNBOOK_FQDN:-${SERVER_ID##*/}.pub.instances.scw.cloud}"

SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=10
)

if [ -n "${SSH_PRIVATE_KEY:-}" ]; then
  SSH_OPTS+=(
    -i "$SSH_PRIVATE_KEY"
    -o IdentitiesOnly=yes
  )
fi

echo
echo "=================================================="
echo "FINAL STACK VERIFICATION"
echo "=================================================="
echo "Target: https://$FQDN"
echo

check_remote() {
  local label="$1"
  local command="$2"

  printf "%-18s " "$label"

  if ssh "${SSH_OPTS[@]}" root@"$PUBLIC_IP" "$command" >/dev/null 2>&1; then
    echo "✓ OK"
  else
    echo "✗ FAILED"
    return 1
  fi
}

FAILED=0

printf "%-18s " "DNS"
if python3 - "$FQDN" "$PUBLIC_IP" <<'PYDNS'
import socket
import sys

host, expected = sys.argv[1:]
try:
    ips = {item[4][0] for item in socket.getaddrinfo(host, 443, family=socket.AF_INET)}
except OSError as exc:
    print(f"DNS lookup failed: {exc}", file=sys.stderr)
    raise SystemExit(1)
raise SystemExit(0 if expected in ips else 1)
PYDNS
then
  echo "✓ OK"
else
  echo "✗ FAILED"
  FAILED=1
fi

printf "%-18s " "HTTPS / Web UI"
if curl -fsS --max-time 25 "https://$FQDN" | grep -i "Runbook AI" >/dev/null; then
  echo "✓ OK"
else
  echo "✗ FAILED"
  FAILED=1
fi

check_remote \
  "Docker" \
  'docker info >/dev/null' || FAILED=1

check_remote \
  "Qdrant" \
  'curl -fsS --max-time 10 http://127.0.0.1:6333/healthz >/dev/null' || FAILED=1

check_remote \
  "LLM" \
  'curl -fsS --max-time 10 http://127.0.0.1:8080/health >/dev/null' || FAILED=1

check_remote \
  "RAG API" \
  'curl -fsS --max-time 10 http://127.0.0.1:8000/health >/dev/null' || FAILED=1

check_remote \
  "Next.js" \
  'curl -fsS --max-time 10 http://127.0.0.1:3000 >/dev/null' || FAILED=1

check_remote \
  "Nginx" \
  'systemctl is-active --quiet nginx' || FAILED=1

check_remote \
  "LLM service" \
  'systemctl is-active --quiet devops-runbooks-llm' || FAILED=1

check_remote \
  "RAG service" \
  'systemctl is-active --quiet devops-runbooks-rag' || FAILED=1

check_remote \
  "Web service" \
  'systemctl is-active --quiet devops-runbooks-web' || FAILED=1

echo

if [ "$FAILED" -ne 0 ]; then
  echo "One or more checks failed."
  echo
  echo "Run:"
  echo "  make status"
  echo "  make logs"
  exit 1
fi

echo "=================================================="
echo "ALL CHECKS PASSED"
echo "=================================================="
echo "Runbook AI: https://$FQDN"
