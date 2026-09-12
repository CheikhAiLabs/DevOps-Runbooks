#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT/infrastructure/terraform-runner"

REPO="CheikhAiLabs/DevOps-Runbooks"
SSH_KEY="$HOME/.ssh/devops-runbooks-github-actions"
SSH_PUB="${SSH_KEY}.pub"

cd "$ROOT"

command -v terraform >/dev/null
command -v gh >/dev/null
command -v scw >/dev/null
command -v jq >/dev/null

[ -f "$SSH_KEY" ] || {
  echo "Missing SSH key: $SSH_KEY"
  exit 1
}

[ -f "$SSH_PUB" ] || {
  echo "Missing SSH public key: $SSH_PUB"
  exit 1
}

PROJECT_ID="$(
  awk -F= '
    /^[[:space:]]*project_id[[:space:]]*=/ {
      gsub(/[ "[:space:]]/, "", $2)
      print $2
      exit
    }
  ' infrastructure/terraform/terraform.tfvars
)"

[ -n "$PROJECT_ID" ] || {
  echo "Unable to determine Scaleway project_id"
  exit 1
}

OPERATOR_CIDR="$(curl -4 -fsS https://api.ipify.org)/32"

export TF_VAR_project_id="$PROJECT_ID"
export TF_VAR_operator_cidr="$OPERATOR_CIDR"

export AWS_ACCESS_KEY_ID="${SCW_ACCESS_KEY:?SCW_ACCESS_KEY must be exported}"
export AWS_SECRET_ACCESS_KEY="${SCW_SECRET_KEY:?SCW_SECRET_KEY must be exported}"
export AWS_DEFAULT_REGION="fr-par"
export AWS_PAGER=""

echo "==> Scaleway project: $PROJECT_ID"
echo "==> Operator CIDR:    $OPERATOR_CIDR"

echo "==> Ensuring deployment SSH key exists in Scaleway project"

PUBKEY="$(cat "$SSH_PUB")"

if ! scw iam ssh-key list project-id="$PROJECT_ID" -o json \
  | jq -e --arg key "$PUBKEY" '.[] | select(.public_key == $key)' \
  >/dev/null; then

  scw iam ssh-key create \
    name="github-actions-devops-runbooks" \
    public-key="$PUBKEY" \
    project-id="$PROJECT_ID" \
    >/dev/null
fi

echo "==> Terraform init"
terraform -chdir="$TF_DIR" init

echo "==> Terraform plan"
terraform -chdir="$TF_DIR" plan

echo "==> Terraform apply"
terraform -chdir="$TF_DIR" apply \
  -auto-approve \
  -input=false

RUNNER_IP="$(terraform -chdir="$TF_DIR" output -raw runner_public_ip)"
RUNNER_CIDR="$(terraform -chdir="$TF_DIR" output -raw runner_cidr)"

echo "==> Runner IP: $RUNNER_IP"

echo "==> Waiting for SSH"

READY=0

for i in $(seq 1 60); do
  if ssh \
    -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    root@"$RUNNER_IP" true >/dev/null 2>&1; then

    READY=1
    break
  fi

  echo "SSH attempt $i/60"
  sleep 5
done

[ "$READY" -eq 1 ] || {
  echo "Runner SSH did not become available."
  exit 1
}

echo "==> Generating GitHub runner registration token"

RUNNER_TOKEN="$(
  gh api \
    --method POST \
    "repos/$REPO/actions/runners/registration-token" \
    --jq '.token'
)"

RUNNER_VERSION="$(
  gh api repos/actions/runner/releases/latest \
    --jq '.tag_name' |
    sed 's/^v//'
)"

echo "==> Installing GitHub Actions runner $RUNNER_VERSION"

ssh \
  -i "$SSH_KEY" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  root@"$RUNNER_IP" \
  "RUNNER_TOKEN='$RUNNER_TOKEN' RUNNER_VERSION='$RUNNER_VERSION' REPO='$REPO' bash -s" <<'REMOTE'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
  ca-certificates \
  curl \
  git \
  rsync \
  unzip \
  openssh-client

id github-runner >/dev/null 2>&1 || \
  useradd \
    --create-home \
    --shell /bin/bash \
    github-runner

mkdir -p /opt/actions-runner
cd /opt/actions-runner

if [ ! -x ./config.sh ]; then
  curl -fsSL \
    -o runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

  tar xzf runner.tar.gz
  rm runner.tar.gz
fi

chown -R github-runner:github-runner /opt/actions-runner

./bin/installdependencies.sh

if [ ! -f .runner ]; then
  sudo -u github-runner ./config.sh \
    --unattended \
    --url "https://github.com/${REPO}" \
    --token "$RUNNER_TOKEN" \
    --name "scaleway-devops-runbooks-01" \
    --labels "scaleway,devops-runbooks,production" \
    --work "_work"
fi

if ! systemctl list-unit-files \
  | grep -q '^actions.runner.'; then

  ./svc.sh install github-runner
fi

./svc.sh start

sleep 3

./svc.sh status
REMOTE

echo "==> Saving runner CIDR in GitHub production environment"

gh variable set RUNNER_CIDR \
  --env production \
  --repo "$REPO" \
  --body "$RUNNER_CIDR"

echo
echo "========================================"
echo "Self-hosted runner ready"
echo "IP:   $RUNNER_IP"
echo "CIDR: $RUNNER_CIDR"
echo "========================================"
