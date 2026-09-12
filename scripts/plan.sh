#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_TF="$ROOT/infrastructure/terraform"
RUNNER_TF="$ROOT/infrastructure/terraform-runner"
REPO="CheikhAiLabs/DevOps-Runbooks"

cd "$ROOT"

echo
echo "=================================================="
echo "TERRAFORM PLAN"
echo "=================================================="
echo

PROJECT_ID="${SCW_PROJECT_ID:-${TF_VAR_project_id:-}}"

if [ -z "$PROJECT_ID" ] && [ -f "$APP_TF/terraform.tfvars" ]; then
  PROJECT_ID="$(
    awk -F'"' \
      '/^[[:space:]]*project_id[[:space:]]*=/ {print $2; exit}' \
      "$APP_TF/terraform.tfvars"
  )"
fi

if [ -z "$PROJECT_ID" ]; then
  echo "ERROR: Unable to determine Scaleway Project ID."
  exit 1
fi

OPERATOR_CIDR="${TF_VAR_operator_cidr:-}"

if [ -z "$OPERATOR_CIDR" ] && command -v gh >/dev/null 2>&1; then
  OPERATOR_CIDR="$(
    gh variable get OPERATOR_CIDR \
      --env production \
      --repo "$REPO" 2>/dev/null || true
  )"
fi

if [ -z "$OPERATOR_CIDR" ]; then
  OPERATOR_IP="$(curl -4 -fsS https://api.ipify.org)"
  OPERATOR_CIDR="${OPERATOR_IP}/32"
fi

SCW_ACCESS_KEY_VALUE="${SCW_ACCESS_KEY:-}"
SCW_SECRET_KEY_VALUE="${SCW_SECRET_KEY:-}"

if [ -z "$SCW_ACCESS_KEY_VALUE" ] && command -v scw >/dev/null 2>&1; then
  SCW_ACCESS_KEY_VALUE="$(scw config get access-key)"
fi

if [ -z "$SCW_SECRET_KEY_VALUE" ] && command -v scw >/dev/null 2>&1; then
  SCW_SECRET_KEY_VALUE="$(scw config get secret-key)"
fi

if [ -n "$SCW_ACCESS_KEY_VALUE" ]; then
  export SCW_ACCESS_KEY="$SCW_ACCESS_KEY_VALUE"
  export AWS_ACCESS_KEY_ID="$SCW_ACCESS_KEY_VALUE"
fi

if [ -n "$SCW_SECRET_KEY_VALUE" ]; then
  export SCW_SECRET_KEY="$SCW_SECRET_KEY_VALUE"
  export AWS_SECRET_ACCESS_KEY="$SCW_SECRET_KEY_VALUE"
fi

export AWS_DEFAULT_REGION="fr-par"
export AWS_PAGER=""

export TF_VAR_project_id="$PROJECT_ID"
export TF_VAR_operator_cidr="$OPERATOR_CIDR"
export TF_VAR_ssh_allowed_cidr="$OPERATOR_CIDR"

echo "Scaleway Project: $PROJECT_ID"
echo "Operator CIDR:    $OPERATOR_CIDR"
echo

echo "=================================================="
echo "1/2  RUNNER STACK"
echo "=================================================="
echo

terraform -chdir="$RUNNER_TF" init -input=false
terraform -chdir="$RUNNER_TF" validate
terraform -chdir="$RUNNER_TF" plan -input=false

RUNNER_CIDR="$(
  terraform \
    -chdir="$RUNNER_TF" \
    output -raw runner_cidr 2>/dev/null || true
)"

if [ -n "$RUNNER_CIDR" ]; then
  export TF_VAR_runner_cidr="$RUNNER_CIDR"
  echo
  echo "Runner CIDR:      $RUNNER_CIDR"
else
  export TF_VAR_runner_cidr=""
  echo
  echo "Runner CIDR:      not currently deployed"
fi

echo
echo "=================================================="
echo "2/2  APPLICATION STACK"
echo "=================================================="
echo

terraform -chdir="$APP_TF" init -input=false
terraform -chdir="$APP_TF" validate
terraform -chdir="$APP_TF" plan -input=false

echo
echo "=================================================="
echo "✓ TERRAFORM PLAN COMPLETED"
echo "=================================================="
echo
