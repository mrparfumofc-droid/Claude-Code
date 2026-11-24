#!/usr/bin/env python3
"""Busca fotos livres no Wikimedia Commons (categoria "Quality images", licenças
CC0, domínio público ou CC BY — sem "compartilha igual") para os fundos do editor
de imagem. Reduz para 1440 px e grava numa pasta com `fundos.json`
(tema, arquivo, miniatura, autor, licença, origem).

As fotos não ficam no repositório: vão para o bucket público "fundos" do
Supabase. Uso: python tool/fetch_backgrounds.py PASTA_SAIDA [--por-tema 14]
"""
import argparse
import html
import io
import json
import pathlib
import re
import sys
import time
import urllib.parse
import urllib.request

from PIL import Image, ImageOps

THEMES = {
    "Céu": ["clouds sky", "sunbeams clouds"],
    "Montanhas": ["mountain landscape", "mountains sunrise"],
    "Mar": ["sea waves", "ocean horizon"],
    "Pôr do sol": ["sunset landscape", "sunrise"],
    "Campos": ["wheat field", "meadow"],
    "Flores": ["flower field", "lily flower"],
    "Floresta": ["forest light", "forest path"],
    "Deserto": ["desert dunes", "Negev desert"],
    "Noite": ["starry sky", "milky way"],
    "Água": ["river landscape", "lake reflection"],
    "Israel": ["Jerusalem old city", "Sea of Galilee"],
}

UA = {"User-Agent": "BibliaJG-backgrounds/1.0 (personal Bible app; wikimedia API)"}
API = "https://commons.wikimedia.org/w/api.php"
OK_LICENSE = re.compile(r"^(cc0|public domain|pd|cc by [0-9.]+)", re.I)


def get(url: str, timeout: int = 90) -> bytes:
    for i in range(4):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except Exception:  # noqa: BLE001
            if i == 3:
                raise
            time.sleep(3 * (i + 1))
    raise RuntimeError


def search(q: str) -> list[dict]:
    params = urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": f'{q} filetype:bitmap incategory:"Quality_images"',
        "gsrnamespace": 6, "gsrlimit": 50,
        "prop": "imageinfo", "iiprop": "url|size|extmetadata", "iiurlwidth": 1440,
    })
    data = json.loads(get(f"{API}?{params}"))
    pages = sorted(data.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 0))
    return pages


def clean(s: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", s or "")).strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--por-tema", type=int, default=14)
    a = ap.parse_args()
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    items, seen = [], set()
    for theme, queries in THEMES.items():
        got = 0
        slug = re.sub(r"[^a-z0-9]+", "-", theme.lower().translate(str.maketrans("éáóúíâêôãç", "eaouiaeoac"))).strip("-")
        for q in queries:
            if got >= a.por_tema:
                break
            try:
                pages = search(q)
            except Exception as e:  # noqa: BLE001
                print(f"busca falhou {q}: {e}", file=sys.stderr)
                continue
            for p in pages:
                if got >= a.por_tema:
                    break
                ii = (p.get("imageinfo") or [{}])[0]
                meta = ii.get("extmetadata", {})
                lic = clean(meta.get("LicenseShortName", {}).get("value", ""))
                if p["title"] in seen or not OK_LICENSE.match(lic) or "sa" in lic.lower().split():
                    continue
                if (ii.get("width") or 0) < 1600 or not ii.get("thumburl"):
                    continue
                seen.add(p["title"])
                try:
                    img = Image.open(io.BytesIO(get(ii["thumburl"])))
                    img = ImageOps.exif_transpose(img).convert("RGB")
                except Exception as e:  # noqa: BLE001
                    print(f"  falhou {p['title']}: {e}", file=sys.stderr)
                    continue
                img.thumbnail((1440, 1440))
                name = f"{slug}-{got + 1:02d}.jpg"
                img.save(out / name, "JPEG", quality=82, optimize=True, progressive=True)
                thumb = img.copy()
                thumb.thumbnail((240, 240))
                thumb.save(out / f"t-{name}", "JPEG", quality=75)
                items.append({
                    "tema": theme, "file": name, "thumb": f"t-{name}",
                    "autor": clean(meta.get("Artist", {}).get("value", ""))[:80],
                    "licenca": lic, "origem": ii.get("descriptionurl", ""),
                })
                got += 1
                print(f"ok {name} ({lic})")
                time.sleep(0.5)
        print(f"{theme}: {got}")
    (out / "fundos.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(items)} fotos em {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
