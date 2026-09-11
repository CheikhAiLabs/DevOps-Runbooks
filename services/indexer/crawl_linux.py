from __future__ import annotations

import json
import re
import time
from pathlib import Path
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup

BASE = "https://runbook.academy"
CURRICULUM = "https://runbook.academy/courses/linux/curriculum/"
RAW_DIR = Path("/srv/devops-runbooks/data/raw/linux")
MANIFEST = Path("/srv/devops-runbooks/data/manifests/linux.json")
RAW_DIR.mkdir(parents=True, exist_ok=True)
MANIFEST.parent.mkdir(parents=True, exist_ok=True)

session = requests.Session()
session.headers.update({"User-Agent": "DevOps-Runbooks-RAG/1.0 educational indexing"})

def slugify(url: str) -> str:
    slug = urlparse(url).path.strip("/").split("/")[-1] or "index"
    return re.sub(r"[^a-zA-Z0-9._-]+", "-", slug)[:180]

print(f"[CRAWL] Reading curriculum: {CURRICULUM}", flush=True)
r = session.get(CURRICULUM, timeout=30)
r.raise_for_status()
soup = BeautifulSoup(r.text, "lxml")
urls = sorted({
    urljoin(BASE, a["href"]).split("#")[0]
    for a in soup.find_all("a", href=True)
    if urlparse(urljoin(BASE, a["href"])).netloc == "runbook.academy"
    and urlparse(urljoin(BASE, a["href"])).path.startswith("/courses/linux/lessons/")
})
if not urls:
    raise RuntimeError("No Linux lesson URLs found in curriculum")
print(f"[CRAWL] Lesson URLs found: {len(urls)}", flush=True)
manifest=[]
for i,url in enumerate(urls,1):
    out=RAW_DIR/f"{slugify(url)}.html"
    if out.exists() and out.stat().st_size > 1000:
        status="cached"
    else:
        resp=session.get(url,timeout=30)
        resp.raise_for_status()
        out.write_text(resp.text,encoding="utf-8")
        status="downloaded"
        time.sleep(0.05)
    manifest.append({"url":url,"file":out.name})
    if i % 25 == 0 or i == len(urls):
        print(f"[CRAWL] {i}/{len(urls)} ({i/len(urls)*100:.1f}%) {status}", flush=True)
MANIFEST.write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding="utf-8")
print(f"[CRAWL] Raw documents ready: {len(manifest)}", flush=True)
