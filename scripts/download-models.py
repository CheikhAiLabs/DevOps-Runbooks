#!/usr/bin/env python3
from pathlib import Path
from huggingface_hub import snapshot_download, hf_hub_download

HF=Path("/srv/devops-runbooks/models/huggingface")
LLM=Path("/srv/devops-runbooks/models/llm")
HF.mkdir(parents=True,exist_ok=True); LLM.mkdir(parents=True,exist_ok=True)
for repo in ["Qwen/Qwen3-Embedding-0.6B","Qwen/Qwen3-Reranker-4B"]:
    print(f"Caching {repo}", flush=True)
    snapshot_download(repo_id=repo, cache_dir=str(HF))
filename="Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf"
target=LLM/filename
if not target.exists() or target.stat().st_size < 40_000_000_000:
    print("Downloading Qwen3-Next 80B Q4_K_M (~48 GB)", flush=True)
    hf_hub_download(repo_id="Qwen/Qwen3-Next-80B-A3B-Instruct-GGUF", filename=filename, local_dir=str(LLM))
else:
    print("LLM GGUF already present; skipping", flush=True)
print("Models ready")
