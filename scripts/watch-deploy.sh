#!/usr/bin/env bash
set -euo pipefail

REPO="CheikhAiLabs/DevOps-Runbooks"
WORKFLOW="deploy.yml"
MODE="${1:-dispatch}"
VALUE="${2:-}"

find_run_for_commit() {
  local sha="$1"
  local run_id=""

  for _ in $(seq 1 30); do
    run_id="$(
      gh run list \
        --repo "$REPO" \
        --workflow "$WORKFLOW" \
        --commit "$sha" \
        --limit 1 \
        --json databaseId \
        --jq '.[0].databaseId // empty'
    )"

    if [ -n "$run_id" ]; then
      printf '%s\n' "$run_id"
      return 0
    fi

    sleep 2
  done

  return 1
}

case "$MODE" in
  dispatch)
    echo "Triggering production deployment..."

    trigger_output="$(
      gh workflow run "$WORKFLOW" \
        --repo "$REPO" \
        --ref main 2>&1
    )"

    printf '%s\n' "$trigger_output"

    RUN_ID="$(
      printf '%s\n' "$trigger_output" \
        | sed -nE 's#.*actions/runs/([0-9]+).*#\1#p' \
        | tail -1
    )"

    if [ -z "$RUN_ID" ]; then
      sleep 3

      RUN_ID="$(
        gh run list \
          --repo "$REPO" \
          --workflow "$WORKFLOW" \
          --branch main \
          --event workflow_dispatch \
          --limit 1 \
          --json databaseId \
          --jq '.[0].databaseId'
      )"
    fi
    ;;

  commit)
    [ -n "$VALUE" ] || {
      echo "ERROR: commit SHA is required."
      exit 1
    }

    echo "Waiting for deployment workflow for commit:"
    echo "$VALUE"

    RUN_ID="$(find_run_for_commit "$VALUE")" || {
      echo "ERROR: deployment workflow was not found."
      exit 1
    }
    ;;

  *)
    echo "Usage:"
    echo "  $0 dispatch"
    echo "  $0 commit <sha>"
    exit 1
    ;;
esac

echo
echo "Deployment run: $RUN_ID"
echo "https://github.com/$REPO/actions/runs/$RUN_ID"
echo

gh run watch "$RUN_ID" \
  --repo "$REPO" \
  --exit-status

echo
echo "========================================"
echo "✓ Deployment completed successfully"
echo "========================================"

APP_URL="$(
  gh run view "$RUN_ID" \
    --repo "$REPO" \
    --log 2>/dev/null \
    | sed -nE 's#.*Application URL:[[:space:]]*(https://[^[:space:]]+).*#\1#p' \
    | tail -1
)"

if [ -z "$APP_URL" ]; then
  APP_URL="$(
    terraform \
      -chdir=infrastructure/terraform \
      output -raw https_url 2>/dev/null || true
  )"
fi

if [ -n "$APP_URL" ]; then
  echo
  echo "Application URL:"
  echo "$APP_URL"
fi

echo
