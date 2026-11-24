#!/usr/bin/env python3
"""Baixa do Wikisource (pt) os hinos de domínio público do Cantor Cristão e de
"Hinos religiosos" e grava `hinos.json` (número, título, autor, estrofes, fonte).

O Wikisource só publica obras em domínio público. Uso:
  python tool/fetch_hymns.py SAIDA.json [--amostra]
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request

API = "https://pt.wikisource.org/w/api.php"
UA = {"User-Agent": "BibliaJG/1.0 (personal Bible app; https://github.com/mrparfumofc-droid/Claude-Code)"}
CATS = [("Categoria:Cantor Cristão", "Cantor Cristão"), ("Categoria:Hinos religiosos", "Hinos tradicionais"),
        ("Categoria:Hinos cristãos", "Hinos tradicionais")]


def api(params: dict) -> dict:
    url = API + "?" + urllib.parse.urlencode({**params, "format": "json", "maxlag": 5})
    for i in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return json.loads(r.read())
        except Exception as e:  # noqa: BLE001
            print(f"  aguardando ({e})", file=sys.stderr)
            time.sleep(10 * (i + 1))
    raise RuntimeError("Wikisource não respondeu")


def clean(wt: str) -> tuple[str, list[str], int | None]:
    """Tira predefinições e marcações; devolve (autor, estrofes, número)."""
    author = ""
    m = re.search(r"\|\s*autor\s*=\s*([^\n|}]*)", wt)
    if m:
        author = re.sub(r"\[\[(?:[^|\]]*\|)?([^\]]*)\]\]", r"\1", m.group(1)).strip()
    num = None
    m = re.search(r"\|\s*(?:seção|secao|número|numero)\s*=\s*[^\n|}]*?(\d{1,3})", wt)
    if m:
        num = int(m.group(1))
    body = wt
    # Remove predefinições {{...}} (inclusive aninhadas).
    for _ in range(5):
        body = re.sub(r"\{\{[^{}]*\}\}", "", body)
    body = re.sub(r"<ref[^>]*>.*?</ref>|<ref[^/]*/>", "", body, flags=re.S)
    body = re.sub(r"</?(poem|div|center|span|small|big|p|br\s*/?)[^>]*>", "\n", body, flags=re.I)
    body = re.sub(r"\[\[(?:Categoria|Category|Ficheiro|File|Imagem):[^\]]*\]\]", "", body, flags=re.I)
    body = re.sub(r"\[\[(?:[^|\]]*\|)?([^\]]*)\]\]", r"\1", body)
    body = re.sub(r"'{2,}", "", body)
    body = re.sub(r"^[=:;*#]+\s*|\s*=+$", "", body, flags=re.M)
    body = re.sub(r"__[A-Z]+__", "", body)
    lines = [l.rstrip() for l in body.splitlines()]
    stanzas, cur = [], []
    for l in lines:
        if l.strip():
            cur.append(l.strip())
        elif cur:
            stanzas.append("\n".join(cur))
            cur = []
    if cur:
        stanzas.append("\n".join(cur))
    return author, stanzas, num


def main() -> int:
    out_path = sys.argv[1]
    sample = "--amostra" in sys.argv
    titles: list[tuple[str, str]] = []
    for cat, source in CATS:
        r = api({"action": "query", "list": "categorymembers", "cmtitle": cat, "cmlimit": 500, "cmnamespace": 0})
        titles += [(m["title"], source) for m in r["query"]["categorymembers"]]
        time.sleep(1)
    # Números do Cantor Cristão, pelo índice da obra ("*12. [[Título|...]]").
    idx = api({"action": "query", "prop": "revisions", "rvprop": "content", "rvslots": "main",
               "titles": "Cantor Cristão"})
    idx_wt = next(iter(idx["query"]["pages"].values()))["revisions"][0]["slots"]["main"]["*"]
    numbers = {m.group(2).strip(): int(m.group(1)) for m in re.finditer(r"\*\s*(\d{1,3})\.\s*\[\[([^|\]]+)", idx_wt)}
    seen, hymns = set(), []
    titles = [t for t in titles if not (t[0] in seen or seen.add(t[0]))]
    if sample:
        titles = titles[:2]
    for i in range(0, len(titles), 50):
        chunk = titles[i:i + 50]
        r = api({"action": "query", "prop": "revisions", "rvprop": "content", "rvslots": "main",
                 "titles": "|".join(t for t, _ in chunk)})
        pages = {p["title"]: p for p in r["query"]["pages"].values()}
        for t, source in chunk:
            p = pages.get(t)
            if not p or "revisions" not in p:
                continue
            wt = p["revisions"][0]["slots"]["main"]["*"]
            if sample:
                print(wt[:1500])
                print("=" * 40)
            author, stanzas, num = clean(wt)
            if t == "Cantor Cristão" or len(stanzas) < 2:
                continue
            if source == "Cantor Cristão":
                num = numbers.get(t, num)
            title = re.sub(r"\s*\([^)]*\)$", "", t)  # "Adoração (Ken)" -> "Adoração"
            if author.lower() in ("anônimo", "anonimo", "desconhecido"):
                author = ""
            hymns.append({"titulo": title, "autor": author, "fonte": source, "numero": num, "estrofes": stanzas})
        time.sleep(2)
    hymns.sort(key=lambda h: (h["fonte"], h["numero"] or 9999, h["titulo"]))
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(hymns, f, ensure_ascii=False, indent=1)
    print(f"{len(hymns)} hinos em {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
