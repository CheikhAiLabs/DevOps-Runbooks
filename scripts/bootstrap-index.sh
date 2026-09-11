#!/usr/bin/env bash
set -euo pipefail
VENV=/srv/devops-runbooks/app/venv
INDEXER=/srv/devops-runbooks/app/indexer
COLLECTION=runbook_linux_v4
if curl -fsS "http://127.0.0.1:6333/collections/${COLLECTION}" >/dev/null 2>&1 && [ "${FORCE_REINDEX:-0}" != "1" ]; then
  echo "[INDEX] Qdrant collection ${COLLECTION} already exists; skipping indexing"
  exit 0
fi
export HF_HOME=/srv/devops-runbooks/models/huggingface
export OMP_NUM_THREADS=48 MKL_NUM_THREADS=48
export PYTHONUNBUFFERED=1
cd "$INDEXER"
echo "[INDEX 1/4] Crawling RunBook Academy Linux"
"$VENV/bin/python" -u crawl_linux.py
echo "[INDEX 2/4] Cleaning documents"
"$VENV/bin/python" -u clean_linux.py
echo "[INDEX 3/4] Building chunks"
"$VENV/bin/python" -u chunk_linux.py
echo "[INDEX 4/4] Embedding and writing vectors to Qdrant"
"$VENV/bin/python" -u index_linux.py
