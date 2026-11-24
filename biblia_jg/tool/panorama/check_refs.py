"""Confere todas as referências do panorama contra o texto de uma Bíblia do app (capítulo e versículo existem)."""
import json, pathlib, re, sys
REPO = pathlib.Path(r"D:\Claude Code\biblia-app-repo\biblia_jg")
ABBR = "Gn Êx Lv Nm Dt Js Jz Rt 1Sm 2Sm 1Rs 2Rs 1Cr 2Cr Ed Ne Et Jó Sl Pv Ec Ct Is Jr Lm Ez Dn Os Jl Am Ob Jn Mq Na Hc Sf Ag Zc Ml Mt Mc Lc Jo At Rm 1Co 2Co Gl Ef Fp Cl 1Ts 2Ts 1Tm 2Tm Tt Fm Hb Tg 1Pe 2Pe 1Jo 2Jo 3Jo Jd Ap".split()
bfile = next(p for p in sorted((REPO / "assets" / "bibles").glob("*.json")) if p.stem.lower() in ("arc", "acf", "ara", "kja") or True)
raw = json.loads(bfile.read_text(encoding="utf-8"))
books = raw["books"] if isinstance(raw, dict) else raw
chap = [[len(c) for c in b["chapters"]] for b in books]
print("Bíblia usada:", bfile.name, len(chap), "livros")
PAT = re.compile(r"^(\S+) (\d+)(?::(\d+)(?:-(\d+))?)?(?:–(\d+)(?::(\d+))?)?$")
bad = []
def check(ref, where, only_book=None):
    m = PAT.match(ref)
    if not m or m.group(1) not in ABBR:
        bad.append((where, ref, "formato")); return
    b = ABBR.index(m.group(1)); c = int(m.group(2))
    if only_book is not None and b != only_book: bad.append((where, ref, "outro livro"))
    if c < 1 or c > len(chap[b]): bad.append((where, ref, f"capítulo {c} não existe (livro tem {len(chap[b])})")); return
    if m.group(3):
        v = int(m.group(3)); e = int(m.group(4) or v)
        if v < 1 or e > chap[b][c - 1] or e < v: bad.append((where, ref, f"versículos fora (cap. tem {chap[b][c-1]})"))
    if m.group(5):
        c2 = int(m.group(5))
        if c2 > len(chap[b]) or c2 < c: bad.append((where, ref, f"capítulo final {c2} fora (livro tem {len(chap[b])})"))
        elif m.group(6) and int(m.group(6)) > chap[b][c2 - 1]: bad.append((where, ref, f"versículo final fora (cap. {c2} tem {chap[b][c2-1]})"))
d = json.loads((REPO / "assets" / "data" / "panorama.json").read_text(encoding="utf-8"))
for n in d["arvore"]["nos"]:
    for r in n["refs"]: check(r, "árvore " + n["id"])
for s in d["arvore"]["passos"]: check(s["ref"], "passo")
for k in ("unido", "israel", "juda"):
    for r in d["reis"][k]: check(r["ref"], "rei " + r["nome"])
for m in d["reis"]["marcos"]: check(m["ref"], "marco")
for p in d["profetas"]: check(p["ref"], "profeta " + p["nome"], p["livro"])
last = {}
for b in d["livros"]:
    check(b["chave"], f"livro {b['n']} chave", b["n"] - 1)
    prev = (0, 0)
    for e in b["acontecimentos"]:
        check(e["ref"], f"livro {b['n']} {e['titulo']}", b["n"] - 1)
        m = PAT.match(e["ref"])
        if m:
            cur = (int(m.group(2)), int(m.group(3) or 0))
            if cur < prev: bad.append((f"livro {b['n']}", e["ref"], f"fora de ordem (depois de {prev})"))
            prev = cur
print(len(bad), "problemas")
for x in bad: print("  ", x)
if "--chaves" in sys.argv:
    for b in d["livros"]:
        m = PAT.match(b["chave"]); bi = ABBR.index(m.group(1)); c = int(m.group(2)); v = int(m.group(3)); e = int(m.group(4) or v)
        t = " ".join(re.sub(r"</?J>", "", x) for x in books[bi]["chapters"][c - 1][v - 1:e])
        print(f"{b['chave']:12s} {t[:110]}")
