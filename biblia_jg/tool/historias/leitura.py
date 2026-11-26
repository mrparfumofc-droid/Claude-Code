"""Leitura da Bíblia gravada com a voz padrão do app (Algieba). Só versões livres (domínio público
ou licença livre): o texto das outras pertence às editoras e não pode ser gravado.

  python leitura.py                 atende a fila (capítulos que o leitor pediu no app) e adianta os seguintes
  python leitura.py N               o mesmo, com no máximo N pedidos de voz nesta rodada
  python leitura.py blivre 43 3     grava um capítulo (João 3 da Bíblia Livre), mesmo fora da fila

Na nuvem (bucket público "historias"):
  leitura/<versão>/<livro>-<cap>.ogg    áudio (Opus, 24 kbps, mono)
  leitura/<versão>/<livro>-<cap>.json   {"d": duração em ms, "m": [início de cada versículo em ms]}
  leitura/<versão>/index.json           {"versao": n, "c": ["43-3", ...]}  capítulos gravados
"""
import json, pathlib, re, subprocess, sys, time, urllib.request

here = pathlib.Path(__file__).parent
sys.path.insert(0, str(here))
import midia  # noqa: E402
from midia import FN, HEAD, NO_WINDOW, OUT, REPO, TTS_MODELS, _load, _speak, sent, upload  # noqa: E402

VOZ = "Algieba"
LIVRES = ["blivre", "alm1911", "tb", "kjv"]
PARTE = 3000    # caracteres por pedido de voz (capítulo maior é dividido entre versículos)
ADIANTE = 2     # capítulos seguintes gravados depois de cada pedido do leitor
TAXA = 24000    # o Gemini devolve PCM de 16 bits, mono, 24 kHz
DIR = OUT / "leitura"
_biblias: dict = {}


def _post(body: dict) -> dict:
    req = urllib.request.Request(FN, data=json.dumps(body).encode(), method="POST",
                                 headers={**HEAD, "Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=60).read())


def biblia(v: str) -> dict:
    if v not in _biblias:
        _biblias[v] = json.loads((REPO / "assets" / "bibles" / f"{v}.json").read_text(encoding="utf-8"))
    return _biblias[v]


def limpo(t: str) -> str:
    return " ".join(re.sub(r"</?J>", "", t).split())


def titulo(v: str, b: int, c: int) -> str:
    livro = biblia(v)["books"][b - 1]
    nome, n = livro["name"], len(livro["chapters"])
    if n == 1:
        return nome + "."
    if v == "kjv":
        return f"{nome}, chapter {c}."
    if b == 19:
        return f"Salmo {c}."
    return f"{nome}, capítulo {c}."


def partes(head: str, versos: list) -> list:
    """Divide o capítulo em pedidos de voz. Cada parte é uma lista de trechos; o título é o 1º trecho."""
    out, cur, size = [], [head], len(head)
    for t in versos:
        if size + len(t) > PARTE and len(cur) > (1 if not out else 0):
            out.append(cur)
            cur, size = [], 0
        cur.append(t)
        size += len(t) + 1
    if cur:
        out.append(cur)
    return out


def _pcm(raw: bytes) -> bytes:
    """Tira o cabeçalho se vier WAV; devolve só as amostras."""
    if raw[:4] == b"RIFF":
        i = raw.find(b"data")
        return raw[i + 8:] if i > 0 else raw[44:]
    return raw


def silencios(pcm: bytes, minimo: float = 0.18) -> list:
    """Trechos de silêncio (início, fim) em segundos."""
    import numpy as np
    x = np.frombuffer(pcm[: len(pcm) // 2 * 2], dtype="<i2").astype(np.float32)
    win = TAXA // 50  # 20 ms
    n = len(x) // win
    if n == 0:
        return []
    rms = np.sqrt((x[: n * win].reshape(n, win) ** 2).mean(axis=1))
    lim = max(120.0, float(np.percentile(rms, 90)) * 0.06)
    quiet = rms < lim
    out, start = [], None
    for i, q in enumerate(quiet):
        if q and start is None:
            start = i
        elif not q and start is not None:
            if (i - start) * 0.02 >= minimo:
                out.append((start * 0.02, i * 0.02))
            start = None
    return out


def marcas(pcm: bytes, trechos: list) -> list:
    """Início de cada trecho, em segundos: estimado pelo tamanho do texto e ajustado à pausa mais próxima."""
    dur = len(pcm) / 2 / TAXA
    pesos = [len(t) + 14 for t in trechos]
    total = float(sum(pesos))
    sil = silencios(pcm)
    out, acc, prev = [0.0], 0.0, 0.0
    for i in range(1, len(trechos)):
        acc += pesos[i - 1]
        est = dur * acc / total
        janela = max(2.5, dur * 0.06)
        best, score = None, None
        for a, b in sil:
            mid = (a + b) / 2
            if mid <= prev + 0.3 or abs(mid - est) > janela:
                continue
            sc = (b - a) * 2.0 - abs(mid - est)  # prefere pausa longa e perto do estimado
            if score is None or sc > score:
                best, score = (a, b), sc
        t = max(prev + 0.2, (best[1] - 0.06) if best else est)
        out.append(t)
        prev = t
    return out


def _to_ogg(pcm: bytes, ogg: pathlib.Path) -> bool:
    tmp = ogg.with_suffix(".tmp")
    tmp.write_bytes(pcm)
    r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(TAXA), "-ac", "1", "-i", str(tmp),
                        "-c:a", "libopus", "-b:a", "24k", "-application", "voip", str(ogg)],
                       capture_output=True, text=True, creationflags=NO_WINDOW)
    tmp.unlink(missing_ok=True)
    if r.returncode != 0 or not ogg.exists() or ogg.stat().st_size < 4000:
        print("  ffmpeg falhou em", ogg.name, r.stderr[:200], flush=True)
        ogg.unlink(missing_ok=True)
        return False
    return True


def existe(v: str, b: int, c: int) -> bool:
    return 1 <= b <= 66 and 1 <= c <= len(biblia(v)["books"][b - 1]["chapters"])


def pronto(v: str, b: int, c: int, reg: dict) -> bool:
    return f"leitura/{v}/{b}-{c}.ogg" in reg and f"leitura/{v}/{b}-{c}.json" in reg


def gravar(v: str, b: int, c: int, models: list, reg: dict, refused: dict) -> tuple:
    """Grava e publica um capítulo. Devolve (deu certo, pedidos de voz usados)."""
    versos = [limpo(t) for t in biblia(v)["books"][b - 1]["chapters"][c - 1]]
    grupos = partes(titulo(v, b, c), versos)
    pcm_all, inicio, usados = b"", [], 0
    for gi, trechos in enumerate(grupos):
        raw = _speak("\n\n".join(trechos), VOZ, models, f"{v} {b}-{c} parte {gi + 1}", refused)
        usados += 1
        if raw is None:
            return False, usados
        pcm = _pcm(raw)
        base = len(pcm_all) / 2 / TAXA
        m = marcas(pcm, trechos)
        if gi == 0:
            m = m[1:]  # o 1º trecho é o título falado
        inicio += [base + t for t in m]
        pcm_all += pcm + b"\x00" * int(TAXA * 0.35) * 2  # pequena pausa entre as partes
        time.sleep(4)
    if len(inicio) != len(versos):
        print(f"  {v} {b}-{c}: marcas {len(inicio)} != versículos {len(versos)}", flush=True)
        return False, usados
    d = DIR / v
    d.mkdir(parents=True, exist_ok=True)
    ogg, side = d / f"{b}-{c}.ogg", d / f"{b}-{c}.json"
    if not _to_ogg(pcm_all, ogg):
        return False, usados
    side.write_text(json.dumps({"d": round(len(pcm_all) / 2 / TAXA * 1000), "m": [round(t * 1000) for t in inicio], "voz": VOZ}),
                    encoding="utf-8")
    ok = upload(f"leitura/{v}/{b}-{c}.ogg", ogg.read_bytes(), reg) and upload(f"leitura/{v}/{b}-{c}.json", side.read_bytes(), reg)
    if ok:
        print(f"gravado {v} {biblia(v)['books'][b - 1]['name']} {c} ({ogg.stat().st_size // 1024} KB, {len(grupos)} parte(s))", flush=True)
    return ok, usados


def publicar_indices(reg: dict) -> None:
    por = {}
    for path in reg:
        m = re.fullmatch(r"leitura/([a-z0-9]+)/(\d+-\d+)\.ogg", path)
        if m and f"leitura/{m.group(1)}/{m.group(2)}.json" in reg:
            por.setdefault(m.group(1), []).append(m.group(2))
    for v, caps in por.items():
        caps.sort(key=lambda k: tuple(int(x) for x in k.split("-")))
        upload(f"leitura/{v}/index.json", json.dumps({"versao": int(time.time()), "voz": VOZ, "c": caps}).encode(), None)
        print(f"índice {v}: {len(caps)} capítulos gravados", flush=True)


def rodar(limite: int, models: list | None = None, avulso: tuple | None = None) -> int:
    """Atende a fila. Devolve quantos pedidos de voz usou."""
    models = list(TTS_MODELS) if models is None else models
    reg, refused = sent(), _load(midia.SKIP, {})
    if avulso:
        fila = [avulso]
    else:
        try:
            fila = [(r["versao"], int(r["livro"]), int(r["cap"])) for r in _post({"fila": True}).get("fila", [])]
        except Exception as e:  # noqa: BLE001
            print("fila: não consegui ler", e, flush=True)
            return 0
    pedidos = [j for j in fila if j[0] in LIVRES and existe(*j)]
    adiante = [(v, b, c + k) for v, b, c in pedidos for k in range(1, ADIANTE + 1) if existe(v, b, c + k)]
    feitos, usados, novos = [], 0, 0
    for job in dict.fromkeys(pedidos + adiante):
        if pronto(*job, reg):
            if job in pedidos:
                feitos.append(list(job))
            continue
        if not models or usados >= limite:
            continue
        ok, n = gravar(*job, models, reg, refused)
        usados += n
        if ok:
            novos += 1
            if job in pedidos:
                feitos.append(list(job))
    lixo = [list(j) for j in fila if j not in pedidos]  # pedidos inválidos saem da fila
    if (feitos or lixo) and not avulso:
        try:
            _post({"feito": feitos + lixo})
        except Exception as e:  # noqa: BLE001
            print("fila: não consegui dar baixa", e, flush=True)
    if novos:
        publicar_indices(reg)
    if fila or novos:
        print(f"leitura: {novos} capítulos novos, {usados} pedidos de voz; fila tinha {len(fila)}"
              + ("" if models else " (cota de hoje esgotada)"), flush=True)
    return usados


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) == 3:
        rodar(20, avulso=(a[0], int(a[1]), int(a[2])))
    else:
        rodar(int(a[0]) if a else 40)
