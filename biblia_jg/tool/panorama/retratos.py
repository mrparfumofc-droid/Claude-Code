"""Retratos dos personagens do Panorama, recortados das ilustrações das Histórias bíblicas.

  python retratos.py grade <pasta de saída> <cena> [cena ...]   folhas com grade (para marcar o rosto)
  python retratos.py cortar [pasta de saída da conferência]     recorta conforme retratos_def.json
  python retratos.py enviar                                     envia para a nuvem e grava o índice

retratos_def.json: { "<id>": {"cena": "<chave da ilustração>", "cx": %, "cy": %, "s": %, "nomes": ["Nome", ...]} }
  cx, cy = centro do recorte em % da largura e da altura; s = lado do quadrado em % da largura.
"""
import json, os, pathlib, sys, time

from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).parent
HIST = pathlib.Path(r"D:\Claude Code\mapas-biblia\historias")
RAW = HIST / "raw"
DEF = HERE / "retratos_def.json"
OUT = HERE / "retratos_out"
REPO = pathlib.Path(r"D:\Claude Code\biblia-app-repo\biblia_jg")
SIZE = 320


def raw_path(key: str) -> pathlib.Path:
    for f in RAW.iterdir():
        if f.is_file() and f.stem == key:
            return f
    raise SystemExit(f"sem ilustração bruta: {key}")


def grade(out_dir: str, keys: list[str]) -> None:
    W, H, COLS, PER = 780, 439, 2, 6
    for page in range(0, len(keys), PER):
        chunk = keys[page:page + PER]
        rows = (len(chunk) + COLS - 1) // COLS
        sheet = Image.new("RGB", (W * COLS, (H + 18) * rows), "black")
        d = ImageDraw.Draw(sheet)
        for i, key in enumerate(chunk):
            im = Image.open(raw_path(key)).convert("RGB").resize((W, H), Image.LANCZOS)
            g = ImageDraw.Draw(im)
            for p in range(5, 100, 5):
                x, y = W * p // 100, H * p // 100
                major = p % 10 == 0
                g.line([(x, 0), (x, H)], fill=(255, 255, 0) if major else (255, 255, 255), width=1)
                g.line([(0, y), (W, y)], fill=(0, 255, 255) if major else (255, 255, 255), width=1)
                if major:
                    g.rectangle([x + 1, 0, x + 15, 10], fill="black")
                    g.text((x + 2, 0), str(p), fill=(255, 255, 0))
                    g.rectangle([0, y + 1, 14, y + 11], fill="black")
                    g.text((1, y + 1), str(p), fill=(0, 255, 255))
            ox, oy = (i % COLS) * W, (i // COLS) * (H + 18)
            sheet.paste(im, (ox, oy))
            d.text((ox + 4, oy + H + 3), key, fill=(255, 255, 0))
        name = os.path.join(out_dir, f"grade{page // PER}.jpg")
        sheet.save(name, quality=82)
        print(name)


def crop(spec: dict) -> Image.Image:
    im = Image.open(raw_path(spec["cena"])).convert("RGB")
    w, h = im.size
    s = spec["s"] / 100 * w
    cx, cy = spec["cx"] / 100 * w, spec["cy"] / 100 * h
    x0 = min(max(cx - s / 2, 0), w - s)
    y0 = min(max(cy - s / 2, 0), h - s)
    return im.crop((round(x0), round(y0), round(x0 + s), round(y0 + s))).resize((SIZE, SIZE), Image.LANCZOS)


def cortar(qa_dir: str | None) -> None:
    defs = json.loads(DEF.read_text(encoding="utf-8"))
    OUT.mkdir(exist_ok=True)
    keep = set()
    for pid, spec in defs.items():
        crop(spec).save(OUT / f"{pid}.jpg", quality=88)
        keep.add(f"{pid}.jpg")
    for f in OUT.iterdir():
        if f.name not in keep:
            f.unlink()
    print(len(defs), "retratos em", OUT)
    if qa_dir:
        ids = list(defs)
        T, L, COLS, PER = 190, 18, 8, 48
        for page in range(0, len(ids), PER):
            chunk = ids[page:page + PER]
            rows = (len(chunk) + COLS - 1) // COLS
            sheet = Image.new("RGB", (T * COLS, (T + L) * rows), "black")
            d = ImageDraw.Draw(sheet)
            for i, pid in enumerate(chunk):
                im = Image.open(OUT / f"{pid}.jpg").resize((T, T), Image.LANCZOS)
                mask = Image.new("L", (T, T), 0)
                ImageDraw.Draw(mask).ellipse([2, 2, T - 3, T - 3], fill=255)
                x, y = (i % COLS) * T, (i // COLS) * (T + L)
                sheet.paste(im, (x, y), mask)
                d.text((x + 4, y + T + 3), pid, fill=(255, 255, 0))
            name = os.path.join(qa_dir, f"retratos{page // PER}.jpg")
            sheet.save(name, quality=85)
            print(name)


def enviar() -> None:
    sys.path.insert(0, str(HIST))
    os.chdir(HIST)
    import midia  # noqa: E402  (usa a chave de envio que fica só no PC)

    defs = json.loads(DEF.read_text(encoding="utf-8"))
    ok = 0
    for pid in defs:
        if midia.upload(f"retratos/{pid}.jpg", (OUT / f"{pid}.jpg").read_bytes(), None):
            ok += 1
    index = {
        "versao": int(time.strftime("%y%m%d%H%M")),
        "retratos": {pid: spec["nomes"] for pid, spec in defs.items()},
    }
    raw = json.dumps(index, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    sent = midia.upload("retratos.json", raw, None)
    (REPO / "assets" / "data" / "retratos.json").write_bytes(raw)
    print(f"retratos na nuvem: {ok}/{len(defs)} · índice versão {index['versao']}: {'ok' if sent else 'FALHOU'}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "grade":
        grade(sys.argv[2], sys.argv[3:])
    elif cmd == "cortar":
        cortar(sys.argv[2] if len(sys.argv) > 2 else None)
    elif cmd == "enviar":
        enviar()
    else:
        print(__doc__)
