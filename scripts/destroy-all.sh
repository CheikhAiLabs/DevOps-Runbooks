#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER_TF="$ROOT/infrastructure/terraform-runner"
REPO="CheikhAiLabs/DevOps-Runbooks"
RUNNER_NAME="scaleway-devops-runbooks-01"

cd "$ROOT"

echo
echo "=================================================="
echo "FULL PLATFORM DESTRUCTION"
echo "=================================================="
echo
echo "This will destroy:"
echo "  - application VM"
echo "  - application public IP"
echo "  - application Security Group"
echo "  - application data volume"
echo "  - GitHub Actions runner VM"
echo "  - runner public IP"
echo "  - runner Security Group"
echo
echo "Terraform remote state bucket is preserved."
echo

printf "Type DESTROY-ALL to continue: "
read -r CONFIRM

if [ "$CONFIRM" != "DESTROY-ALL" ]; then
  echo "Cancelled."
  exit 1
fi

if [ -z "${SCW_ACCESS_KEY:-}" ]; then
  export SCW_ACCESS_KEY="$(scw config get access-key)"
fi

if [ -z "${SCW_SECRET_KEY:-}" ]; then
  export SCW_SECRET_KEY="$(scw config get secret-key)"
fi

export AWS_ACCESS_KEY_ID="$SCW_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SCW_SECRET_KEY"
export AWS_DEFAULT_REGION="fr-par"
export AWS_PAGER=""

PROJECT_ID="$(
  awk -F= '
    /^[[:space:]]*project_id[[:space:]]*=/ {
      gsub(/[ "[:space:]]/, "", $2)
      print $2
      exit
    }
  ' infrastructure/terraform/terraform.tfvars
)"

if [ -z "$PROJECT_ID" ]; then
  echo "ERROR: Unable to determine Scaleway project_id."
  exit 1
fi

export TF_VAR_project_id="$PROJECT_ID"
export TF_VAR_operator_cidr="$(curl -4 -fsS https://api.ipify.org)/32"

echo
echo "==> 1/3 Destroying application stack"
./scripts/destroy.sh

echo
echo "==> 2/3 Removing GitHub runner registration"

RUNNER_ID="$(
  gh api \
    "repos/$REPO/actions/runners" \
    --jq ".runners[] | select(.name==\"$RUNNER_NAME\") | .id" \
    | head -1
)"

if [ -n "$RUNNER_ID" ]; then
  gh api \
    --method DELETE \
    "repos/$REPO/actions/runners/$RUNNER_ID"

  echo "GitHub runner registration removed."
else
  echo "Runner is not registered in GitHub."
fi

echo
echo "==> 3/3 Destroying runner infrastructure"

terraform -chdir="$RUNNER_TF" init -input=false

terraform -chdir="$RUNNER_TF" destroy \
  -auto-approve \
  -input=false

gh variable delete RUNNER_CIDR \
  --env production \
  --repo "$REPO" \
  >/dev/null 2>&1 || true

echo
echo "=================================================="
echo "✓ FULL PLATFORM DESTRUCTION COMPLETED"
echo "=================================================="
echo
echo "Application stack: destroyed"
echo "GitHub runner:      destroyed"
echo "Remote state:       preserved"
echo
echo "Recreate everything with:"
echo
echo "  make deploy-all"
echo
