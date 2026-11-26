"""Narrações dos textos explicativos do app (Panorama, árvores, guia do Novo Testamento) com a voz
padrão (Algieba). A gravação é achada pelo próprio texto: `narr/<chave>.mp3`, e a lista das chaves
gravadas vai em `narr/index.json`. O app (lib/services/narration_cloud.dart) calcula a mesma chave.

  python narr.py            grava o que falta (até a cota do dia) e publica o índice
  python narr.py N          no máximo N narrações nesta rodada
  python narr.py lista      só mostra quantos textos existem e quantos faltam
"""
import json, pathlib, sys, time

here = pathlib.Path(__file__).parent
sys.path.insert(0, str(here))
import leitura  # noqa: E402
import midia  # noqa: E402
from midia import OUT, REPO, TTS_MODELS, _load, _speak, _to_mp3, sent, upload  # noqa: E402

VOZ = "Algieba"
DIR = OUT / "narr"
DATA = REPO / "assets" / "data"


def chave(text: str) -> str:
    """Igual a NarrationCloud.keyFor no app: dois FNV-1a de 32 bits sobre o UTF-8 normalizado."""
    b = " ".join(text.split()).encode("utf-8")

    def fnv(data) -> int:
        h = 0x811C9DC5
        for x in data:
            h = ((h ^ x) * 0x01000193) & 0xFFFFFFFF
        return h

    return f"{fnv(b):08x}{fnv(reversed(b)):08x}"


def _json(name: str):
    p = DATA / name
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else None


def _andar(node, campos: tuple, out: list, minimo: int = 60) -> None:
    """Junta os textos dos campos pedidos, em qualquer profundidade."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k in campos and isinstance(v, str) and len(v) >= minimo:
                out.append(v)
            else:
                _andar(v, campos, out, minimo)
    elif isinstance(node, list):
        for v in node:
            _andar(v, campos, out, minimo)


def textos() -> list:
    """Todos os textos que o app narra passo a passo, na ordem em que vale a pena gravar.

    Cada entrada de FONTES diz: arquivo de dados, caminho até a lista de apresentações e os campos
    de texto falados. O app fala exatamente o conteúdo desses campos.
    """
    out: list = []
    for nome, raiz, campos in FONTES:
        j = _json(nome)
        if j is None:
            continue
        node = j
        for k in raiz:
            node = node.get(k) if isinstance(node, dict) else None
            if node is None:
                break
        if node is not None:
            _andar(node, campos, out)
    return list(dict.fromkeys(out))


# (arquivo em assets/data, caminho até o trecho com as apresentações, campos narrados)
FONTES = [
    ("panorama.json", ("arvore", "passos"), ("texto",)),
]


def rodar(limite: int, models: list | None = None, so_listar: bool = False) -> int:
    models = list(TTS_MODELS) if models is None else models
    DIR.mkdir(parents=True, exist_ok=True)
    reg, refused = sent(), _load(midia.SKIP, {})
    # Textos que o app narrou com a voz do aparelho (pedidos pela fila narr_fila), antes dos do pacote.
    fila = []
    try:
        fila = [r["texto"] for r in leitura._post({"narr_fila": True}).get("fila", [])]
    except Exception as e:  # noqa: BLE001
        print("fila de narrações: não consegui ler", e, flush=True)
    todos = list(dict.fromkeys(fila + textos()))
    falta = [t for t in todos if f"narr/{chave(t)}.mp3" not in reg]
    print(f"narrações do Panorama: {len(todos)} textos, {len(todos) - len(falta)} gravados, {len(falta)} faltando", flush=True)
    if so_listar:
        return 0
    usados, novos = 0, 0
    for t in falta:
        if not models or usados >= limite:
            break
        k = chave(t)
        mp3 = DIR / f"{k}.mp3"
        if not mp3.exists():
            pcm = _speak(t, VOZ, models, "narr " + k, refused)
            usados += 1
            if pcm is None or not _to_mp3(pcm, mp3):
                continue
            time.sleep(4)
        if upload(f"narr/{k}.mp3", mp3.read_bytes(), reg):
            novos += 1
    feitos = [chave(t) for t in fila if f"narr/{chave(t)}.mp3" in reg]
    if feitos:
        try:
            leitura._post({"narr_feito": feitos})
        except Exception as e:  # noqa: BLE001
            print("fila de narrações: não consegui dar baixa", e, flush=True)
    if novos or not (DIR / "index.json").exists():
        chaves = sorted(p[5:-4] for p in reg if p.startswith("narr/") and p.endswith(".mp3"))
        raw = json.dumps({"versao": int(time.time()), "voz": VOZ, "h": chaves}).encode()
        (DIR / "index.json").write_bytes(raw)
        upload("narr/index.json", raw, None)
        print(f"índice das narrações: {len(chaves)} gravadas", flush=True)
    return usados


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "lista":
        rodar(0, so_listar=True)
    else:
        rodar(int(a[0]) if a else 40)
