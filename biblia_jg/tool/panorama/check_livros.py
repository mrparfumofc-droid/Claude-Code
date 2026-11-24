"""Confere os arquivos livros_a.json (1–22), livros_b.json (23–44) e livros_c.json (45–66).
Uso: python check_livros.py a   (ou b, c; sem argumento confere os três)"""
import json, pathlib, re, sys, unicodedata
here = pathlib.Path(__file__).parent
ABBR = "Gn Êx Lv Nm Dt Js Jz Rt 1Sm 2Sm 1Rs 2Rs 1Cr 2Cr Ed Ne Et Jó Sl Pv Ec Ct Is Jr Lm Ez Dn Os Jl Am Ob Jn Mq Na Hc Sf Ag Zc Ml Mt Mc Lc Jo At Rm 1Co 2Co Gl Ef Fp Cl 1Ts 2Ts 1Tm 2Tm Tt Fm Hb Tg 1Pe 2Pe 1Jo 2Jo 3Jo Jd Ap".split()
RANGES = {"a": (1, 22), "b": (23, 44), "c": (45, 66)}
REF = re.compile(r"^(" + "|".join(re.escape(a) for a in ABBR) + r") \d+(:\d+(-\d+)?)?(–\d+(:\d+)?)?$")
bad = 0
for part in (sys.argv[1:] or ["a", "b", "c"]):
    lo, hi = RANGES[part]
    p = here / f"livros_{part}.json"
    if not p.exists():
        print("FALTA", p.name); bad += 1; continue
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        print("JSON inválido", p.name, e); bad += 1; continue
    nums = [b.get("n") for b in data]
    if nums != list(range(lo, hi + 1)):
        print(f"ERRO {p.name}: esperado n de {lo} a {hi} em ordem, veio {nums}"); bad += 1
    for b in data:
        probs = []
        n = b.get("n", 0)
        ab = ABBR[n - 1] if 1 <= n <= 66 else "?"
        if b.get("abrev") != ab: probs.append(f"abrev deve ser {ab}")
        for k, lo_c, hi_c in (("autor", 3, 60), ("data", 4, 40), ("tema", 20, 95), ("cristo", 40, 170)):
            v = b.get(k, "")
            if not (lo_c <= len(v) <= hi_c): probs.append(f"{k}: {len(v)} caracteres ({lo_c}–{hi_c})")
        if len(b.get("autor_nota", "")) > 70: probs.append("autor_nota: até 70 caracteres")
        w = len(b.get("resumo", "").split())
        if not 35 <= w <= 75: probs.append(f"resumo: {w} palavras (35–75)")
        if b.get("rotulo") not in ("acontecimentos", "assuntos"): probs.append("rotulo deve ser acontecimentos ou assuntos")
        ch = b.get("chave", "")
        if not REF.match(ch) or not ch.startswith(ab + " ") or ":" not in ch or "–" in ch: probs.append(f"chave inválida: {ch!r} (um trecho curto deste livro, ex.: {ab} 1:1-2)")
        ps = b.get("personagens", [])
        if not 3 <= len(ps) <= 8: probs.append(f"personagens: {len(ps)} (3–8)")
        for x in ps:
            if not x.get("nome") or not (8 <= len(x.get("nota", "")) <= 80): probs.append(f"personagem {x.get('nome')!r}: nota de 8–80 caracteres")
        ev = b.get("acontecimentos", [])
        if not 3 <= len(ev) <= 10: probs.append(f"acontecimentos: {len(ev)} (3–10)")
        for x in ev:
            if not (3 <= len(x.get("titulo", "")) <= 60): probs.append(f"título de acontecimento fora de 3–60: {x.get('titulo')!r}")
            if not REF.match(x.get("ref", "")) or not x.get("ref", "").startswith(ab + " "): probs.append(f"ref inválida: {x.get('ref')!r}")
        txt = json.dumps(b, ensure_ascii=False)
        if re.search(r"[*#_\[\]]{2}|\n", txt): probs.append("tem markdown ou quebra de linha")
        print(("OK   " if not probs else "ERRO ") + f"{n:2d} {ab}", "; ".join(probs))
        bad += bool(probs)
sys.exit(1 if bad else 0)
