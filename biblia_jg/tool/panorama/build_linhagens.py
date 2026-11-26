"""Gera assets/data/linhagens.json (quadros de linhagens do Panorama) e tool/panorama/arte_linhagens.json.

Uso:  python tool/panorama/build_linhagens.py
Os textos ficam em tool/panorama/linhagens/q_*.py (um arquivo por quadro) e a lista de ilustrações
novas em linhagens/arte.py. O script confere ligações, sobreposição de nós, tamanho dos passos,
referências bíblicas (contra uma Bíblia do app, se estiver baixada), chaves de ilustração e retratos.
"""
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))

# Cores (ARGB em hexadecimal, como no panorama.json)
ROXO, VERDE, OURO, AZUL, CIANO, VIOLETA = "FF8E24AA", "FF2E7D32", "FF8D6708", "FF1565C0", "FF00838F", "FF6A1B9A"
MARINHO, ROSA, CINZA, VERMELHO, TEAL, LARANJA, MARROM = "FF1B2A4A", "FFC2185B", "FF546E7A", "FFB23A2E", "FF00796B", "FFD4630A", "FF795548"

# Tamanho (largura, altura) de cada tipo de nó.
SIZES = {"destaque": (164, 58), "pessoa": (150, 46), "mini": (132, 28), "marco": (230, 62), "grupo": (200, 46), "elo": (180, 22)}


class Quadro:
    def __init__(self, id, titulo, sub, cor, capa, intro):
        self.d = {"id": id, "titulo": titulo, "sub": sub, "cor": cor, "capa": capa, "intro": intro}
        self.nos, self.lig, self.casais, self.faixas, self.passos = [], [], [], [], []
        self.ids = {}

    def no(self, id, nome, tipo, x, y, sub="", texto="", refs=(), arte=None, retrato=None, cor=None, fatos=(), link=None,
           w=None, h=None):
        """retrato: None = sem retrato; True = procura pelo próprio nome; texto = nome exato no índice de retratos."""
        assert id not in self.ids, f"id repetido: {id}"
        tw, th = SIZES[tipo]
        d = {"id": id, "nome": nome, "tipo": tipo, "x": x, "y": y, "w": w or tw, "h": h or th}
        if sub: d["sub"] = sub
        if texto: d["texto"] = texto
        if refs: d["refs"] = list(refs)
        if arte: d["arte"] = arte
        if retrato is True: d["retrato"] = nome
        elif retrato: d["retrato"] = retrato
        if cor: d["cor"] = cor
        if fatos: d["fatos"] = [list(f) for f in fatos]
        if link: d["link"] = link
        self.ids[id] = d
        self.nos.append(d)
        return id

    def liga(self, de, para, tracejada=False, h=False, meio=None):
        e = {"de": [de] if isinstance(de, str) else list(de), "para": para}
        if tracejada: e["estilo"] = "tracejada"
        if h: e["forma"] = "h"
        if meio is not None: e["meio"] = meio
        self.lig.append(e)

    def cadeia(self, ids, **kw):
        for a, b in zip(ids, ids[1:]):
            self.liga(a, b, **kw)

    def casal(self, a, b):
        self.casais.append([a, b])

    def faixa(self, x, y, w, h, titulo="", sub="", cor=None, base=False):
        f = {"x": x, "y": y, "w": w, "h": h, "titulo": titulo}
        if sub: f["sub"] = sub
        if cor: f["cor"] = cor
        if base: f["base"] = True
        self.faixas.append(f)

    def passo(self, nos, titulo, texto, ref, arte):
        self.passos.append({"nos": list(nos), "titulo": titulo, "texto": texto, "ref": ref, "arte": arte})

    def json(self):
        right = max([n["x"] + n["w"] / 2 for n in self.nos] + [f["x"] + f["w"] for f in self.faixas])
        bottom = max([n["y"] + n["h"] / 2 for n in self.nos] + [f["y"] + f["h"] for f in self.faixas])
        return {**self.d, "largura": round(right + 30), "altura": round(bottom + 44), "faixas": self.faixas,
                "nos": self.nos, "ligacoes": self.lig, "casais": self.casais, "passos": self.passos}


# ------------------------------------------------------------------ conferência

ABBR = ("Gn Êx Lv Nm Dt Js Jz Rt 1Sm 2Sm 1Rs 2Rs 1Cr 2Cr Ed Ne Et Jó Sl Pv Ec Ct Is Jr Lm Ez Dn Os Jl Am Ob Jn Mq Na Hc Sf "
        "Ag Zc Ml Mt Mc Lc Jo At Rm 1Co 2Co Gl Ef Fp Cl 1Ts 2Ts 1Tm 2Tm Tt Fm Hb Tg 1Pe 2Pe 1Jo 2Jo 3Jo Jd Ap").split()
PAT = re.compile(r"^(\S+) (\d+)(?::(\d+)(?:-(\d+))?)?(?:–(\d+)(?::(\d+))?)?$")


def _bible():
    """Versículos por capítulo de uma Bíblia do app (None se as Bíblias não foram baixadas)."""
    for name in ("ara", "arc", "acf", "naa", "nvi"):
        p = REPO / "assets" / "bibles" / f"{name}.json"
        if p.exists():
            raw = json.loads(p.read_text(encoding="utf-8"))
            books = raw["books"] if isinstance(raw, dict) else raw
            return name, [[len(c) for c in b["chapters"]] for b in books]
    return None, None


def check_ref(ref, chap):
    m = PAT.match(ref)
    if not m or m.group(1) not in ABBR:
        return "formato"
    if chap is None:
        return None
    b = ABBR.index(m.group(1)); c = int(m.group(2))
    if c < 1 or c > len(chap[b]):
        return f"capítulo {c} não existe"
    if m.group(3):
        v = int(m.group(3)); e = int(m.group(4) or v)
        if v < 1 or e > chap[b][c - 1] or e < v:
            return f"versículos fora (cap. tem {chap[b][c - 1]})"
    if m.group(5):
        c2 = int(m.group(5))
        if c2 > len(chap[b]) or c2 < c:
            return f"capítulo final {c2} fora"
        if m.group(6) and int(m.group(6)) > chap[b][c2 - 1]:
            return "versículo final fora"
    return None


def confere(quadros, arte):
    bad = []
    bname, chap = _bible()
    hist = json.loads((REPO / "assets/data/historias.json").read_text(encoding="utf-8"))
    existing = {c["img"] for s in hist["historias"] for c in s["cenas"] if c.get("i")}
    portraits = {n for names in json.loads((REPO / "assets/data/retratos.json").read_text(encoding="utf-8"))["retratos"].values()
                 for n in names}
    new_keys = {a["key"] for a in arte}
    used_old, used_new, missing_portraits, nrefs = set(), set(), {}, 0
    for q in quadros:
        qid = q["id"]
        ids = {n["id"]: n for n in q["nos"]}

        def art(key, where):
            if key is None:
                bad.append((qid, where, "sem ilustração"))
            elif key in existing:
                used_old.add(key)
            elif key in new_keys:
                used_new.add(key)
            else:
                bad.append((qid, where, f"ilustração desconhecida: {key}"))

        art(q["capa"], "capa")
        for n in q["nos"]:
            if n.get("arte"):
                art(n["arte"], n["id"])
            if n["tipo"] == "marco" and not n.get("arte"):
                bad.append((qid, n["id"], "marco sem ilustração"))
            if n.get("retrato") and n["retrato"] not in portraits:
                missing_portraits.setdefault(n["retrato"], []).append(f"{qid}/{n['id']}")
            for r in n.get("refs", []):
                nrefs += 1
                err = check_ref(r, chap)
                if err: bad.append((qid, n["id"], f"{r}: {err}"))
            if n["tipo"] != "elo" and not n.get("texto"):
                bad.append((qid, n["id"], "sem texto"))
            if n.get("link") and n["link"] not in ("abraao", "reis", "historias", "mapas") and not n["link"].startswith("quadro:"):
                bad.append((qid, n["id"], f"link desconhecido: {n['link']}"))
        # Nós que se sobrepõem (com 4 px de folga)
        ns = q["nos"]
        for i, a in enumerate(ns):
            for b in ns[i + 1:]:
                if abs(a["x"] - b["x"]) < (a["w"] + b["w"]) / 2 + 4 and abs(a["y"] - b["y"]) < (a["h"] + b["h"]) / 2 + 4:
                    bad.append((qid, a["id"], f"sobrepõe {b['id']}"))
        for e in q["ligacoes"]:
            for i in e["de"] + [e["para"]]:
                if i not in ids: bad.append((qid, "ligação", f"nó inexistente: {i}"))
        for c in q["casais"]:
            for i in c:
                if i not in ids: bad.append((qid, "casal", f"nó inexistente: {i}"))
        linked = {i for e in q["ligacoes"] for i in e["de"] + [e["para"]]} | {i for c in q["casais"] for i in c}
        in_band = lambda n: any(f["x"] <= n["x"] <= f["x"] + f["w"] and f["y"] <= n["y"] <= f["y"] + f["h"] for f in q["faixas"])
        for n in ns:
            if n["id"] not in linked and not in_band(n):
                bad.append((qid, n["id"], "nó solto (sem ligação e fora de faixa)"))
        shown = set()
        for k, s in enumerate(q["passos"]):
            words = len(s["texto"].split())
            if not 38 <= words <= 92: bad.append((qid, f"passo {k + 1}", f"{words} palavras"))
            art(s["arte"], f"passo {k + 1}")
            nrefs += 1
            err = check_ref(s["ref"], chap)
            if err: bad.append((qid, f"passo {k + 1}", f"{s['ref']}: {err}"))
            if not s["nos"]: bad.append((qid, f"passo {k + 1}", "sem nós"))
            for i in s["nos"]:
                shown.add(i)
                if i not in ids: bad.append((qid, f"passo {k + 1}", f"nó inexistente: {i}"))
        never = [n["id"] for n in ns if n["id"] not in shown and n["tipo"] != "elo"]
        print(f"{qid:10s} {len(ns):3d} nós, {len(q['passos']):2d} passos, {q['largura']}x{q['altura']}"
              + (f" · fora da apresentação: {len(never)}" if never else ""))
    unused = sorted(new_keys - used_new)
    if unused: bad.append(("arte", "-", f"pedidas e não usadas: {unused}"))
    print(f"referências conferidas: {nrefs} (Bíblia: {bname or 'NÃO BAIXADA: só o formato'})")
    print(f"ilustrações já existentes usadas: {len(used_old)} · novas pedidas: {len(used_new)}")
    print("retratos que ainda não existem:", json.dumps(missing_portraits, ensure_ascii=False))
    print(len(bad), "problemas")
    for b in bad: print("  ", b)
    return not bad


def main():
    from linhagens import arte, q_jesus, q_adao, q_linhas, q_apostolos, q_paulo, q_povos
    quadros = [m.build().json() for m in (q_jesus, q_adao, q_linhas, q_apostolos, q_paulo, q_povos)]
    ok = confere(quadros, arte.ARTE)
    out = {"versao": 1, "quadros": quadros}
    (REPO / "assets/data/linhagens.json").write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (HERE / "arte_linhagens.json").write_text(json.dumps(arte.ARTE, ensure_ascii=False, indent=1), encoding="utf-8")
    print("gravado:", (REPO / "assets/data/linhagens.json").stat().st_size // 1024, "KB")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
