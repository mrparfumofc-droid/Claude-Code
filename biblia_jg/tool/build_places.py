#!/usr/bin/env python3
"""Gera assets/data/places.json (lugares bíblicos para os mapas) a partir do
OpenBible.info Bible Geocoding Data (CC BY 4.0).

O nome em português vem do próprio texto da Bíblia: para cada lugar, procura
nos versículos onde ele aparece (Almeida Revista e Atualizada, depois a
Corrigida) o nome próprio mais parecido com o nome em inglês
(Bethel -> Betel, Kadesh -> Cades, Jerusalem -> Jerusalém).

Uso: python tool/build_places.py PASTA_COM_ancient.jsonl
(precisa das Bíblias em assets/bibles: rode antes tool/fetch_bibles.py)
"""
import difflib
import json
import pathlib
import re
import sys
import unicodedata
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OSIS = [
    "Gen", "Exod", "Lev", "Num", "Deut", "Josh", "Judg", "Ruth", "1Sam", "2Sam", "1Kgs", "2Kgs", "1Chr", "2Chr",
    "Ezra", "Neh", "Esth", "Job", "Ps", "Prov", "Eccl", "Song", "Isa", "Jer", "Lam", "Ezek", "Dan", "Hos", "Joel",
    "Amos", "Obad", "Jonah", "Mic", "Nah", "Hab", "Zeph", "Hag", "Zech", "Mal", "Matt", "Mark", "Luke", "John",
    "Acts", "Rom", "1Cor", "2Cor", "Gal", "Eph", "Phil", "Col", "1Thess", "2Thess", "1Tim", "2Tim", "Titus",
    "Phlm", "Heb", "Jas", "1Pet", "2Pet", "1John", "2John", "3John", "Jude", "Rev",
]
PREFIX = [  # (padrão em inglês, prefixo em português)
    (r"^Mount (.+)$", "Monte "), (r"^Mountains? of (.+)$", "Montes de "), (r"^Sea of (.+)$", "Mar de "),
    (r"^(.+) Sea$", "Mar "), (r"^River (.+)$", "Rio "), (r"^(.+) River$", "Rio "), (r"^Valley of (.+)$", "Vale de "),
    (r"^(.+) Valley$", "Vale de "), (r"^Brook (.+)$", "Ribeiro de "), (r"^Wilderness of (.+)$", "Deserto de "),
    (r"^Pool of (.+)$", "Tanque de "), (r"^Plain of (.+)$", "Planície de "), (r"^Land of (.+)$", "Terra de "),
]
STOP = {"Deus", "Senhor", "SENHOR", "Jesus", "Cristo", "Então", "Porque", "Portanto", "Assim", "Disse", "Eis",
        "Quando", "Mas", "Ora", "Também", "Este", "Esta", "Estes", "Ele", "Eles", "Ela", "Rei", "Filho"}


def key(s: str) -> str:
    """Chave "fonética" simples para comparar nomes em inglês e português."""
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = re.sub(r"[^a-z]", "", s)
    for a, b in (("ph", "f"), ("th", "t"), ("sh", "s"), ("ch", "c"), ("k", "c"), ("y", "i"), ("w", "v"),
                 ("j", "i"), ("z", "s"), ("qu", "c"), ("q", "c"), ("x", "s"), ("h", "")):
        s = s.replace(a, b)
    return re.sub(r"(.)\1+", r"\1", s)


def load_bible(name: str):
    p = ROOT / "assets/bibles" / f"{name}.json"
    return json.loads(p.read_text(encoding="utf-8"))["books"] if p.exists() else None


def verse_text(books, osis: str) -> str:
    try:
        b, c, v = osis.split(".")[:3]
        t = books[OSIS.index(b)]["chapters"][int(c) - 1][int(v) - 1]
        return re.sub(r"<[^>]+>", "", t)
    except Exception:  # noqa: BLE001
        return ""


CAND = re.compile(r"\b([A-ZÀ-Ý][a-zà-ÿ']+(?:-[A-ZÀ-Ý]?[a-zà-ÿ']+)*(?:\s(?:de|do|da|dos|das)\s[A-ZÀ-Ý][a-zà-ÿ']+(?:-[A-ZÀ-Ý]?[a-zà-ÿ']+)*)?)")


def best_name(english: str, verses: list[str], bibles) -> str | None:
    base, prefix = english, ""
    for pat, pt in PREFIX:
        m = re.match(pat, english)
        if m:
            base, prefix = m.group(1), pt
            break
    target = key(base)
    if len(target) < 2:
        return None
    counts, scores = Counter(), {}
    for books in bibles:
        for osis in verses[:25]:
            for m in CAND.finditer(verse_text(books, osis)):
                full = m.group(1)
                # "Caná da Galileia" também conta como "Caná".
                for cand in {full, full.split(" ")[0]}:
                    if cand in STOP:
                        continue
                    r = difflib.SequenceMatcher(None, target, key(cand)).ratio()
                    if r >= 0.62:
                        counts[cand] += 1
                        scores[cand] = max(scores.get(cand, 0), r)
        if counts:
            break  # achou na ARA; não precisa da ARC
    if not counts:
        return None
    best = max(counts, key=lambda c: (round(scores[c], 2) + min(counts[c], 10) * 0.02))
    return (prefix + best).replace("Mar de Galileia", "Mar da Galileia")


def main() -> int:
    base = pathlib.Path(sys.argv[1])
    bibles = [b for b in (load_bible("ara"), load_bible("arc")) if b]
    if not bibles:
        print("faltam as Bíblias em assets/bibles (rode tool/fetch_bibles.py)")
        return 1
    places, found = [], 0
    for line in (base / "ancient.jsonl").read_text(encoding="utf-8").splitlines():
        r = json.loads(line)
        ids = r.get("identifications") or []
        if not ids or not ids[0].get("resolutions"):
            continue
        lonlat = ids[0]["resolutions"][0].get("lonlat")
        if not lonlat:
            continue
        lon, lat = (float(x) for x in lonlat.split(","))
        verses = [v["osis"] for v in r.get("verses", [])]
        english = re.sub(r"\s+\d+$", "", r["friendly_id"])
        pt = best_name(english, verses, bibles)
        found += pt is not None
        places.append({
            "i": r["id"], "n": pt or english, "en": english,
            "t": (r.get("types") or ["place"])[0],
            "c": [round(lat, 4), round(lon, 4)],
            "s": int(ids[0].get("score", {}).get("vote_total", 0)),
            "v": verses,
        })
    places.sort(key=lambda p: -p["s"])
    out = ROOT / "assets/data/places.json"
    out.write_text(json.dumps(places, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(places)} lugares, {found} com nome achado na Bíblia; gravado {out} ({out.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
