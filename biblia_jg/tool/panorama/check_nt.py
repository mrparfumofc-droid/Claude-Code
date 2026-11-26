"""Confere assets/data/linha_tempo.json e nt_livros.json: formato, tamanho dos textos, ilustrações e
todas as referências bíblicas (capítulo e versículo existem numa Bíblia do app)."""
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent.parent
ABBR = ("Gn Êx Lv Nm Dt Js Jz Rt 1Sm 2Sm 1Rs 2Rs 1Cr 2Cr Ed Ne Et Jó Sl Pv Ec Ct Is Jr Lm Ez Dn Os Jl Am Ob Jn Mq Na Hc Sf "
        "Ag Zc Ml Mt Mc Lc Jo At Rm 1Co 2Co Gl Ef Fp Cl 1Ts 2Ts 1Tm 2Tm Tt Fm Hb Tg 1Pe 2Pe 1Jo 2Jo 3Jo Jd Ap").split()
PAT = re.compile(r"^(\S+) (\d+)(?::(\d+)(?:-(\d+))?)?(?:–(\d+)(?::(\d+))?)?$")
ICONES = {"public", "groups", "landscape", "shield", "account_balance", "call_split", "lock_clock", "home_work",
          "hourglass_bottom", "wb_sunny", "local_fire_department", "mail", "volunteer_activism", "gavel", "castle",
          "auto_stories", "campaign"}
LINKS = {"", "arvore", "tabernaculo", "reis", "historias", "nt"}
NOVA = ("hist-", "nt-")


def words(s: str) -> int:
    return len(s.split())


def check() -> int:
    data = REPO / "assets" / "data"
    bad: list = []
    warn: list = []

    # Bíblia para conferir capítulos e versículos (as versões são baixadas por tool/fetch_bibles.py).
    chap = None
    for name in ("acf", "arc", "ara", "nvi"):
        f = REPO / "assets" / "bibles" / f"{name}.json"
        if f.exists():
            raw = json.loads(f.read_text(encoding="utf-8"))
            books = raw["books"] if isinstance(raw, dict) else raw
            chap = [[len(c) for c in b["chapters"]] for b in books]
            print("Bíblia usada na conferência:", f.name)
            break
    if chap is None:
        warn.append("nenhuma Bíblia em assets/bibles: só o formato das referências foi conferido")

    nrefs = 0

    def ref(r: str, where: str, only_book=None) -> None:
        nonlocal nrefs
        nrefs += 1
        m = PAT.match(r)
        if not m or m.group(1) not in ABBR:
            bad.append((where, r, "formato"))
            return
        b = ABBR.index(m.group(1))
        c = int(m.group(2))
        if only_book is not None and b != only_book:
            bad.append((where, r, "é de outro livro"))
        if chap is None:
            return
        if c < 1 or c > len(chap[b]):
            bad.append((where, r, f"capítulo {c} não existe (o livro tem {len(chap[b])})"))
            return
        if m.group(3):
            v = int(m.group(3))
            e = int(m.group(4) or v)
            if v < 1 or e > chap[b][c - 1] or e < v:
                bad.append((where, r, f"versículos fora (o capítulo tem {chap[b][c - 1]})"))
        if m.group(5):
            c2 = int(m.group(5))
            if c2 > len(chap[b]) or c2 < c:
                bad.append((where, r, f"capítulo final {c2} fora"))
            elif m.group(6) and int(m.group(6)) > chap[b][c2 - 1]:
                bad.append((where, r, f"versículo final fora (o capítulo {c2} tem {chap[b][c2 - 1]})"))

    hist = json.loads((data / "historias.json").read_text(encoding="utf-8"))
    cenas = {c["img"] for h in hist["historias"] for c in h["cenas"] if c.get("i")}
    historias = {h["id"] for h in hist["historias"]}
    retratos = json.loads((data / "retratos.json").read_text(encoding="utf-8"))["retratos"]
    nomes = {n for v in retratos.values() for n in v}
    novas_def = json.loads((REPO / "tool" / "panorama" / "arte_nt.json").read_text(encoding="utf-8"))
    novas = {a["key"] for a in novas_def}
    if len(novas_def) > 40:
        bad.append(("arte_nt.json", len(novas_def), "mais de 40 ilustrações novas"))
    for a in novas_def:
        if not a["key"].startswith(NOVA) or not a.get("descricao") or not a.get("onde"):
            bad.append(("arte_nt.json", a.get("key"), "entrada incompleta"))
    usadas: set = set()
    velhas: set = set()

    def art(key, where: str, required: bool = False) -> None:
        if not key:
            if required:
                bad.append((where, "", "sem ilustração"))
            return
        if key.startswith(NOVA):
            usadas.add(key)
            if key not in novas:
                bad.append((where, key, "ilustração nova fora de arte_nt.json"))
        elif key not in cenas:
            bad.append((where, key, "ilustração não existe nas histórias"))
        else:
            velhas.add(key)

    # ---------------- linha do tempo ----------------
    tempo = json.loads((data / "linha_tempo.json").read_text(encoding="utf-8"))
    grupos = {g["id"] for g in tempo["grupos"]}
    ids = set()
    n_ev = 0
    com_retrato = sem_retrato = 0
    for e in tempo["epocas"]:
        w = "época " + e["id"]
        if e["id"] in ids:
            bad.append((w, e["id"], "id repetido"))
        ids.add(e["id"])
        if e["grupo"] not in grupos:
            bad.append((w, e["grupo"], "grupo"))
        if e["icone"] not in ICONES:
            bad.append((w, e["icone"], "ícone"))
        if e.get("link", "") not in LINKS:
            bad.append((w, e.get("link"), "link"))
        if not re.fullmatch(r"[0-9A-F]{6}", e["cor"]):
            bad.append((w, e["cor"], "cor"))
        art(e.get("arte"), w, required=True)
        if not 25 <= words(e["texto"]) <= 80:
            bad.append((w, words(e["texto"]), "texto da época fora de 25–80 palavras"))
        for r in e["refs"]:
            ref(r, w)
        if not 5 <= len(e["eventos"]) <= 26:
            bad.append((w, len(e["eventos"]), "número de acontecimentos"))
        for ev in e["eventos"]:
            n_ev += 1
            we = f"{e['id']}: {ev['titulo']}"
            for k in ("ano", "titulo", "texto"):
                if not ev.get(k):
                    bad.append((we, k, "campo vazio"))
            n = words(ev["texto"])
            if not 30 <= n <= 85:
                bad.append((we, n, "texto fora de 30–85 palavras"))
            art(ev.get("arte"), we)
            for r in ev.get("refs", []):
                ref(r, we)
            if e["grupo"] != "igreja" and not ev.get("refs"):
                bad.append((we, "", "acontecimento bíblico sem referência"))
            if ev.get("historia") and ev["historia"] not in historias:
                bad.append((we, ev["historia"], "história não existe"))
            if ev.get("livro") is not None and not 40 <= ev["livro"] <= 66:
                bad.append((we, ev["livro"], "livro fora do Novo Testamento"))
            for p in ev.get("pessoas", []):
                if p in nomes:
                    com_retrato += 1
                else:
                    sem_retrato += 1

    # ---------------- Novo Testamento, livro por livro ----------------
    nt = json.loads((data / "nt_livros.json").read_text(encoding="utf-8"))
    gnt = {g["id"] for g in nt["grupos"]}
    livros = nt["livros"]
    if [b["n"] for b in livros] != list(range(40, 67)):
        bad.append(("nt", [b["n"] for b in livros], "devem ser os livros 40 a 66, em ordem"))
    if sorted(b["ordem"] for b in livros) != list(range(1, 28)):
        bad.append(("nt", "ordem", "a ordem cronológica deve ir de 1 a 27 sem repetir"))
    n_partes = n_pal = 0
    for b in livros:
        w = f"livro {b['n']}"
        bi = b["n"] - 1
        if b["grupo"] not in gnt:
            bad.append((w, b["grupo"], "grupo"))
        for k in ("tema", "autor", "data", "de", "para", "porque"):
            if not b.get(k):
                bad.append((w, k, "campo vazio"))
        if not 35 <= words(b["porque"]) <= 90:
            bad.append((w, words(b["porque"]), "'porque' fora de 35–90 palavras"))
        n_pal += words(b["porque"])
        art(b.get("capa"), w, required=True)
        for h in b.get("historias", []):
            if h not in historias:
                bad.append((w, h, "história não existe"))
        minimo = 3 if b["n"] in (57, 63, 64) else 4
        if not minimo <= len(b["partes"]) <= 9:
            bad.append((w, len(b["partes"]), "número de partes"))
        for p in b["partes"]:
            n_partes += 1
            wp = f"{w}, {p['caps']}"
            n = words(p["texto"])
            n_pal += n
            if not 50 <= n <= 110:
                bad.append((wp, n, "texto fora de 50–110 palavras"))
            art(p.get("arte"), wp, required=True)
            if not p.get("refs"):
                bad.append((wp, "", "parte sem referência"))
            for r in p["refs"]:
                ref(r, wp, bi)
        if not 2 <= len(b["chaves"]) <= 4:
            bad.append((w, len(b["chaves"]), "versículos-chave"))
        for r in b["chaves"]:
            ref(r, w + " chave", bi)
        if len(b["licoes"]) != 3:
            bad.append((w, len(b["licoes"]), "devem ser 3 lições"))
        for lg in b["ligacoes"]:
            for r in lg["refs"]:
                ref(r, w + " ligação")
            if lg.get("livro") is not None and (not 1 <= lg["livro"] <= 66 or lg["livro"] == b["n"]):
                bad.append((w, lg["livro"], "livro da ligação"))

    for k in sorted(novas - usadas):
        warn.append(f"ilustração nova {k} está em arte_nt.json mas não é usada")
    print(f"linha do tempo: {len(tempo['epocas'])} épocas, {n_ev} acontecimentos")
    print(f"guia do NT: {len(livros)} livros, {n_partes} partes, {n_pal} palavras (partes + contexto)")
    print(f"referências conferidas: {nrefs}")
    print(f"ilustrações: {len(velhas)} já existentes em uso, {len(usadas)} novas pedidas (arte_nt.json tem {len(novas)})")
    print(f"pessoas citadas nos acontecimentos: {com_retrato} com retrato, {sem_retrato} sem")
    for x in warn:
        print("aviso:", x)
    print(len(bad), "problemas")
    for x in bad:
        print("  ", x)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(check())
