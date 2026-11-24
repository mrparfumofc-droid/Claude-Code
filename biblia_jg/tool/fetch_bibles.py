#!/usr/bin/env python3
"""Baixa as versões da Bíblia listadas em tool/bibles_manifest.json,
confere o SHA-256 de cada arquivo e grava no formato do app em assets/bibles/.

Os textos não ficam no repositório (são baixados na hora de gerar o APK).

Uso: python3 tool/fetch_bibles.py [--cache PASTA]
"""
import argparse
import hashlib
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request

import enrich

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tool" / "bibles_manifest.json"
OUT = ROOT / "assets" / "bibles"


def fetch(url: str, attempts: int = 6) -> bytes:
    """Baixa com novas tentativas (a fonte às vezes responde 503 por excesso de conexões)."""
    for i in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                return r.read()
        except (urllib.error.URLError, TimeoutError) as e:
            if i == attempts - 1:
                raise
            wait = 5 * 2**i
            print(f"falhou ({e}); nova tentativa em {wait}s", file=sys.stderr)
            time.sleep(wait)
    raise RuntimeError("inalcançável")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", help="pasta com arquivos já baixados (opcional)")
    args = ap.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    headings, woj = enrich.load()
    OUT.mkdir(parents=True, exist_ok=True)
    index = []
    for v in manifest["versions"]:
        raw = None
        if args.cache:
            cached = pathlib.Path(args.cache) / v["file"]
            if cached.exists():
                raw = cached.read_bytes()
        downloaded = raw is None
        if downloaded:
            raw = fetch(manifest["source"] + v["file"])
        digest = hashlib.sha256(raw).hexdigest()
        if digest != v["sha256"]:
            print(f"ERRO: {v['file']} mudou na fonte (sha256 {digest}).", file=sys.stderr)
            return 1
        if downloaded and args.cache:
            # Só guarda no cache depois de conferir o SHA-256.
            pathlib.Path(args.cache).mkdir(parents=True, exist_ok=True)
            (pathlib.Path(args.cache) / v["file"]).write_bytes(raw)
        books = json.loads(raw.decode("utf-8-sig"))
        if len(books) != 66:
            print(f"ERRO: {v['file']} tem {len(books)} livros.", file=sys.stderr)
            return 1
        data = {
            "id": v["id"],
            "name": v["name"],
            "abbrev": v["abbrev"],
            "copyright": v["copyright"],
            "books": [
                {
                    "abbrev": b.get("abbrev", ""),
                    "name": b.get("name", ""),
                    "chapters": [[str(x).strip() for x in c] for c in b["chapters"]],
                }
                for b in books
            ],
        }
        enrich.enrich_books(data["books"], v.get("lang", "pt"), headings, woj)
        path = OUT / f"{v['id']}.json"
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        index.append({k: v[k] for k in ("id", "name", "abbrev", "copyright")} | {"asset": f"assets/bibles/{v['id']}.json"})
        print(f"ok  {v['abbrev']:8} {path.stat().st_size // 1024} KB")

    (OUT / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(index)} versões gravadas em {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
