from pathlib import Path
import json
import re
import unicodedata
from ftfy import fix_text

from bs4 import BeautifulSoup
from markdownify import markdownify as md

RAW = Path("/srv/devops-runbooks/data/raw/linux")
OUT = Path("/srv/devops-runbooks/data/clean/linux-v4")

OUT.mkdir(parents=True, exist_ok=True)

def normalize(text):
    text = fix_text(text)
    replacements = {
        "â€™": "'",
        "â€˜": "'",
        "â€œ": '"',
        "â€": '"',
        "â€“": "-",
        "â€”": "-",
        "Â·": "·",
        "Â": "",
        "â§": "",
        "â": "",
    }

    for a, b in replacements.items():
        text = text.replace(a, b)

    text = unicodedata.normalize("NFKC", text)

    text = re.sub(
        r"Not yet marked complete on this device\.?",
        "",
        text,
        flags=re.I,
    )

    text = re.sub(
        r"\n{3,}",
        "\n\n",
        text
    )

    return text.strip()

count = 0

paths = sorted(RAW.glob("*.html"))
total_paths = len(paths)

for path in paths:

    soup = BeautifulSoup(
        path.read_text(
            encoding="utf-8",
            errors="ignore"
        ),
        "lxml"
    )

    # Strict source: ONLY the real page content container
    main = soup.find("main", id="main")

    if main is None:
        raise RuntimeError(
            f"main#main missing in {path.name}"
        )

    # Remove non-content UI inside main
    for tag in main.select(
        "script, style, noscript, svg, "
        "button, form, input, textarea, "
        "select"
    ):
        tag.decompose()

    # Remove known interactive / quiz fragments
    for node in main.find_all(
        string=re.compile(
            r"Not yet marked complete|"
            r"Submit answers|"
            r"Passing score",
            re.I
        )
    ):
        if node.parent:
            node.parent.decompose()

    # Title
    h1 = main.find("h1")

    if h1:
        title = normalize(
            h1.get_text(" ", strip=True)
        )
    else:
        t = soup.find("title")

        title = normalize(
            t.get_text(" ", strip=True)
            if t
            else path.stem
        )

    title = re.sub(
        r"\s*·\s*Linux\s*·\s*RunBook Academy\s*$",
        "",
        title,
        flags=re.I
    ).strip()

    # Canonical URL derived deterministically
    slug = path.stem

    url = (
        "https://runbook.academy/"
        f"courses/linux/lessons/{slug}/"
    )

    content = md(
        str(main),
        heading_style="ATX",
        strip=["img"],
    )

    content = normalize(content)

    # Drop duplicate H1 if markdown contains it
    content = re.sub(
        r"^#\s+.+?\n+",
        "",
        content,
        count=1,
        flags=re.M,
    ).strip()

    document = f"""---
source: RunBook Academy
course: Linux
title: {json.dumps(title, ensure_ascii=False)}
url: {url}
license: CC BY-SA 4.0
---

# {title}

{content}
"""

    (OUT / path.with_suffix(".md").name).write_text(
        document,
        encoding="utf-8"
    )

    count += 1

    if count % 25 == 0 or count == total_paths:
        print(f"[CLEAN] {count}/{total_paths} ({count/total_paths*100:.1f}%)", flush=True)

print("[CLEAN] Clean V4 documents:", count, flush=True)
