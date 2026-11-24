"""Confere os textos em texto/<id>.json contra o roteiro. Uso: python check_texto.py [id ...]"""
import json, pathlib, re, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from outline import STORIES
here = pathlib.Path(__file__).parent
ids = sys.argv[1:] or [s["id"] for s in STORIES]
bad = 0
for s in STORIES:
    if s["id"] not in ids:
        continue
    p = here / "texto" / f"{s['id']}.json"
    if not p.exists():
        print("FALTA", s["id"]); bad += 1; continue
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        print("JSON inválido", s["id"], e); bad += 1; continue
    cenas = d.get("cenas", [])
    probs = []
    if len(cenas) != len(s["cenas"]):
        probs.append(f"{len(cenas)} cenas, esperado {len(s['cenas'])}")
    for i, t in enumerate(cenas, 1):
        w = len(t.split())
        if not 70 <= w <= 125:
            probs.append(f"cena {i}: {w} palavras (70–125)")
        if re.search(r"[*#_\[\]()]|\d+:\d+", t):
            probs.append(f"cena {i}: tem markdown, parênteses ou referência")
    if not (20 <= len(d.get("resumo", "")) <= 170):
        probs.append("resumo fora de 20–170 caracteres")
    if not (20 <= len(d.get("aplicacao", "")) <= 220):
        probs.append("aplicacao fora de 20–220 caracteres")
    print(("OK   " if not probs else "ERRO ") + s["id"], "; ".join(probs))
    bad += bool(probs)
sys.exit(1 if bad else 0)
