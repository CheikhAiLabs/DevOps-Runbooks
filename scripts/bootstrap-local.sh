#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
command -v terraform >/dev/null || { echo "terraform is required"; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required"; exit 1; }
command -v ssh >/dev/null || { echo "ssh is required"; exit 1; }
VENV="$ROOT/.deploy-venv"
[ -x "$VENV/bin/ansible-playbook" ] || { python3 -m venv "$VENV"; "$VENV/bin/pip" install -q --upgrade pip 'ansible-core==2.19.2'; }
echo "Local deployment tooling ready"
