from __future__ import annotations

import json
import re
from pathlib import Path

SOURCE_DIR = Path(
    "/srv/devops-runbooks/data/clean/linux-v4"
)

OUTPUT = Path(
    "/srv/devops-runbooks/data/chunks/linux-v4/chunks.jsonl"
)

TARGET_CHARS = 1500
MAX_CHARS = 2200
MIN_CHARS = 300
OVERLAP_CHARS = 180


def strip_frontmatter(text):
    return re.sub(
        r"\A---.*?---\s*",
        "",
        text,
        flags=re.S,
    )


def get_meta(raw):
    title_match = re.search(
        r'^title:\s*(.+)$',
        raw,
        re.M,
    )

    url_match = re.search(
        r'^url:\s*(https?://\S+)',
        raw,
        re.M,
    )

    title = ""

    if title_match:
        try:
            title = json.loads(
                title_match.group(1).strip()
            )
        except Exception:
            title = title_match.group(1).strip().strip('"')

    return {
        "title": title,
        "url": url_match.group(1).strip()
        if url_match else "",
    }


def sections(text):
    heading = ""
    buffer = []

    for line in text.splitlines():
        match = re.match(
            r"^(#{1,6})\s+(.+)$",
            line,
        )

        if match:
            if buffer:
                yield heading, "\n".join(buffer).strip()
                buffer = []

            heading = match.group(2).strip()
        else:
            buffer.append(line)

    if buffer:
        yield heading, "\n".join(buffer).strip()


def split_long(text):
    paragraphs = [
        p.strip()
        for p in re.split(r"\n\s*\n", text)
        if p.strip()
    ]

    chunks = []
    current = ""

    for paragraph in paragraphs:
        candidate = (
            current + "\n\n" + paragraph
            if current
            else paragraph
        )

        if len(candidate) <= TARGET_CHARS:
            current = candidate
            continue

        if current:
            chunks.append(current)

        current = paragraph

        while len(current) > MAX_CHARS:
            chunks.append(
                current[:MAX_CHARS]
            )
            current = current[
                MAX_CHARS - OVERLAP_CHARS:
            ]

    if current:
        chunks.append(current)

    return chunks


records = []

files = sorted(
    SOURCE_DIR.glob("*.md")
)

for file_number, file in enumerate(files, 1):
    raw = file.read_text(
        encoding="utf-8",
        errors="ignore",
    )

    meta = get_meta(raw)
    content = strip_frontmatter(raw)

    preliminary = []

    for heading, body in sections(content):
        if not body.strip():
            continue

        for piece in split_long(body):
            preliminary.append({
                "section": heading,
                "body": piece,
            })

    merged = []
    pending = None

    for item in preliminary:
        if pending is None:
            pending = item
            continue

        # Merge tiny chunks with following content
        if len(pending["body"]) < MIN_CHARS:
            combined = (
                pending["body"]
                + "\n\n"
                + item["body"]
            )

            if len(combined) <= MAX_CHARS:
                pending = {
                    "section":
                        pending["section"]
                        or item["section"],
                    "body": combined,
                }
                continue

        merged.append(pending)
        pending = item

    if pending:
        merged.append(pending)

    for idx, item in enumerate(merged):
        text = (
            f"Document: {meta['title']}\n"
            f"Section: {item['section']}\n\n"
            f"{item['body']}"
        ).strip()

        records.append({
            "course": "Linux",
            "title": meta["title"],
            "section": item["section"],
            "url": meta["url"],
            "file": file.name,
            "chunk_index": idx,
            "text": text,
        })

    if file_number % 25 == 0 or file_number == len(files):
        print(
            f"[CHUNK] {file_number}/{len(files)} docs "
            f"({file_number/len(files)*100:.1f}%) | {len(records)} chunks",
            flush=True,
        )

OUTPUT.parent.mkdir(
    parents=True,
    exist_ok=True,
)

with OUTPUT.open(
    "w",
    encoding="utf-8",
) as f:
    for record in records:
        f.write(
            json.dumps(
                record,
                ensure_ascii=False,
            )
            + "\n"
        )

lengths = [
    len(record["text"])
    for record in records
]

print("CHUNK V4 COMPLETE")
print("Documents:", len(files))
print("Chunks:", len(records))
print(
    "Average chars:",
    round(sum(lengths) / len(lengths))
)
print("Min chars:", min(lengths))
print("Max chars:", max(lengths))
print("Output:", OUTPUT)
