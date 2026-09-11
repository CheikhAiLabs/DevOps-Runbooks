from __future__ import annotations

import hashlib
import json
import os
import time
from pathlib import Path

import torch
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    PointStruct,
    VectorParams,
)
from sentence_transformers import SentenceTransformer

MODEL = "Qwen/Qwen3-Embedding-0.6B"
COLLECTION = "runbook_linux_v4"

CHUNKS_FILE = Path(
    "/srv/devops-runbooks/data/chunks/linux-v4/chunks.jsonl"
)

BATCH_SIZE = 8

os.environ["OMP_NUM_THREADS"] = "48"
os.environ["MKL_NUM_THREADS"] = "48"
os.environ["HF_HOME"] = (
    "/srv/devops-runbooks/models/huggingface"
)

torch.set_num_threads(48)

print("Loading chunks...")

records = [
    json.loads(line)
    for line in CHUNKS_FILE.read_text(
        encoding="utf-8"
    ).splitlines()
    if line.strip()
]

print("Chunks:", len(records))

print("Loading embedding model...")

load_start = time.perf_counter()

model = SentenceTransformer(
    MODEL,
    device="cpu"
)

print(
    "Model loaded in:",
    round(time.perf_counter() - load_start, 2),
    "seconds"
)

print("Detecting embedding dimension...")

sample = model.encode(
    ["Linux production administration"],
    normalize_embeddings=True
)

dimension = sample.shape[1]

print("Dimension:", dimension)

qdrant = QdrantClient(
    url="http://127.0.0.1:6333"
)

collections = {
    c.name
    for c in qdrant.get_collections().collections
}

if COLLECTION in collections:
    print(
        f"Deleting existing collection: {COLLECTION}"
    )

    qdrant.delete_collection(
        collection_name=COLLECTION
    )

print(
    f"Creating collection: {COLLECTION}"
)

qdrant.create_collection(
    collection_name=COLLECTION,
    vectors_config=VectorParams(
        size=dimension,
        distance=Distance.COSINE,
        on_disk=True,
    )
)

total = len(records)

print()
print("STARTING EMBEDDING")
print("Batch size:", BATCH_SIZE)
print("Total:", total)
print()

start_total = time.perf_counter()

for start in range(
    0,
    total,
    BATCH_SIZE
):
    batch = records[
        start:start + BATCH_SIZE
    ]

    texts = [
        item["text"]
        for item in batch
    ]

    vectors = model.encode(
        texts,
        batch_size=BATCH_SIZE,
        normalize_embeddings=True,
        show_progress_bar=False
    )

    points = []

    for item, vector in zip(
        batch,
        vectors
    ):
        unique = (
            f"{item['file']}:"
            f"{item['chunk_index']}"
        ).encode()

        point_id = int(
            hashlib.sha256(
                unique
            ).hexdigest()[:15],
            16
        )

        points.append(
            PointStruct(
                id=point_id,
                vector=vector.tolist(),
                payload=item
            )
        )

    qdrant.upsert(
        collection_name=COLLECTION,
        points=points,
        wait=True
    )

    done = min(
        start + BATCH_SIZE,
        total
    )

    elapsed = (
        time.perf_counter()
        - start_total
    )

    rate = (
        done / elapsed
        if elapsed > 0
        else 0
    )

    eta = (
        (total - done) / rate
        if rate > 0
        else 0
    )

    print(
        f"{done}/{total} "
        f"({done/total*100:.1f}%) "
        f"| {rate:.1f} chunks/s "
        f"| ETA {eta/60:.1f} min",
        flush=True
    )

elapsed = (
    time.perf_counter()
    - start_total
)

info = qdrant.get_collection(
    collection_name=COLLECTION
)

print()
print("======================================")
print("INDEXING COMPLETE")
print("======================================")
print("Collection:", COLLECTION)
print("Chunks:", total)
print("Points:", info.points_count)
print(
    "Elapsed:",
    round(elapsed, 2),
    "seconds"
)
print(
    "Average:",
    round(total / elapsed, 2),
    "chunks/sec"
)
