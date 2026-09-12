#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="CheikhAiLabs/DevOps-Runbooks"

cd "$ROOT"

echo
echo "=================================================="
echo "FULL PLATFORM DEPLOYMENT"
echo "=================================================="
echo
echo "1/2  GitHub Actions runner"
echo "2/2  Application stack"
echo

if [ -z "${SCW_ACCESS_KEY:-}" ]; then
  export SCW_ACCESS_KEY="$(scw config get access-key)"
fi

if [ -z "${SCW_SECRET_KEY:-}" ]; then
  export SCW_SECRET_KEY="$(scw config get secret-key)"
fi

if [ -z "$SCW_ACCESS_KEY" ] || [ -z "$SCW_SECRET_KEY" ]; then
  echo "ERROR: Scaleway credentials are unavailable."
  exit 1
fi

echo "==> Deploying persistent GitHub Actions runner"
./scripts/bootstrap-runner.sh

echo
echo "==> Checking runner registration"

for i in $(seq 1 30); do
  STATUS="$(
    gh api \
      "repos/$REPO/actions/runners" \
      --jq '.runners[] | select(.name=="scaleway-devops-runbooks-01") | .status' \
      | head -1
  )"

  if [ "$STATUS" = "online" ]; then
    echo "Runner is online."
    break
  fi

  echo "Waiting for runner: $i/30"
  sleep 5
done

if [ "${STATUS:-}" != "online" ]; then
  echo "ERROR: GitHub Actions runner is not online."
  exit 1
fi

gh workflow enable deploy.yml \
  --repo "$REPO" \
  >/dev/null 2>&1 || true

echo
echo "==> Deploying application stack"
./scripts/watch-deploy.sh dispatch

echo
echo "=================================================="
echo "✓ FULL PLATFORM DEPLOYMENT COMPLETED"
echo "=================================================="

APP_URL="$(
  terraform \
    -chdir=infrastructure/terraform \
    output -raw https_url 2>/dev/null || true
)"

if [ -n "$APP_URL" ]; then
  echo
  echo "Application URL:"
  echo "$APP_URL"
fi

echo
