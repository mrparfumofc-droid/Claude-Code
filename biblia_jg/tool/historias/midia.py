"""Mídias das Histórias bíblicas (app Bíblia JG): prepara, envia para a nuvem e gera o índice.

  python midia.py imagens        raw/*.jpeg -> out/img (1600px), out/thumb (480px), out/dep (profundidade) e envia
  python midia.py audio [N]      narra (Gemini TTS, cota grátis) até N cenas sem áudio, converte para mp3 e envia
  python midia.py indice         gera historias.json (com o que já tem imagem/áudio), grava no app e envia
  python midia.py tudo [N]       imagens + audio + indice
  python midia.py reconstruir    refaz o registro de enviados conferindo a nuvem (se out/enviados.json se perder)

A chave de envio fica em .upload_key (só neste PC). Nada aqui apaga arquivos da nuvem.
"""
import json, pathlib, re, subprocess, sys, time, urllib.error, urllib.request

here = pathlib.Path(__file__).parent
sys.path.insert(0, str(here))
if sys.stdout is None:  # rodando sem janela (tarefa agendada com pythonw): registra num arquivo
    sys.stdout = sys.stderr = open(here / "midia.log", "a", encoding="utf-8")
    print(time.strftime("== %d/%m/%Y %H:%M =="), flush=True)
NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)
from outline import STORIES  # noqa: E402

REPO = pathlib.Path(r"D:\Claude Code\biblia-app-repo\biblia_jg")
OUT = here / "out"
FN = "https://ayjsoixzroxkrnkpkkip.supabase.co/functions/v1/historias-admin"
svc = (REPO / "lib/services/ai_service.dart").read_text(encoding="utf-8")
ANON = re.search(r"'(eyJ[^']+)'", svc).group(1)
ADMIN = (here / ".upload_key").read_text().strip()
HEAD = {"Authorization": "Bearer " + ANON, "apikey": ANON, "x-admin-key": ADMIN}
SENT = OUT / "enviados.json"
TTS_MODELS = ["gemini-3.1-flash-tts-preview", "gemini-2.5-flash-preview-tts", "gemini-3.8-flash-tts", "gemini-3.8-flash-lite-tts"]
# Vozes masculinas oferecidas ao dono para escolher o narrador (a 1ª é a usada enquanto ele não escolhe).
VOZES = ["Charon", "Orus", "Algenib", "Algieba", "Alnilam", "Sadaltager"]
AMOSTRA = ("Uma luz do céu. Saulo já estava perto de Damasco. De repente, por volta do meio-dia, um resplendor de luz "
           "do céu o cercou. Ele caiu por terra e ouviu uma voz que dizia: Saulo, Saulo, por que me persegues?")
PUBLIC = "https://ayjsoixzroxkrnkpkkip.supabase.co/storage/v1/object/public/historias/"


def sent() -> dict:
    return json.loads(SENT.read_text(encoding="utf-8")) if SENT.exists() else {}


def upload(path: str, data: bytes, reg: dict | None) -> bool:
    """Envia um arquivo. Com `reg` (o registro de enviados), pula o que já foi e anota o novo."""
    if reg is not None and reg.get(path) == len(data):
        return True
    req = urllib.request.Request(FN + "?path=" + path, data=data, method="POST",
                                 headers={**HEAD, "Content-Type": "application/octet-stream"})
    for attempt in range(4):
        try:
            res = json.loads(urllib.request.urlopen(req, timeout=120).read())
            if res.get("ok"):
                if reg is not None:
                    reg[path] = len(data)
                    SENT.write_text(json.dumps(reg, indent=0), encoding="utf-8")
                return True
            print("  envio recusado", path, res, flush=True)
            return False
        except Exception as e:  # noqa: BLE001
            print(f"  envio de {path} falhou ({e}); tento de novo", flush=True)
            time.sleep(5 * (attempt + 1))
    return False


# ------------------------------------------------------------------ imagens
def imagens() -> None:
    import numpy as np
    from PIL import Image, ImageFilter
    for d in ("img", "thumb", "dep"):
        (OUT / d).mkdir(parents=True, exist_ok=True)
    session = None
    reg = sent()
    raws = sorted(p for p in (here / "raw").iterdir() if p.is_file() and p.suffix.lower() in (".jpeg", ".jpg", ".png", ".webp"))
    done = 0
    for raw in raws:
        key = raw.stem
        img_p, th_p, dep_p = OUT / "img" / f"{key}.jpg", OUT / "thumb" / f"{key}.jpg", OUT / "dep" / f"{key}.jpg"
        if not (img_p.exists() and th_p.exists() and dep_p.exists()) or img_p.stat().st_mtime < raw.stat().st_mtime:
            im = Image.open(raw).convert("RGB")
            w = 1600
            big = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
            big.save(img_p, "JPEG", quality=82, optimize=True, progressive=True)
            im.resize((480, round(im.height * 480 / im.width)), Image.LANCZOS).save(th_p, "JPEG", quality=76, optimize=True)
            # Profundidade (Depth Anything V2 small, ONNX): claro = perto.
            if session is None:
                import onnxruntime as ort
                session = ort.InferenceSession(str(here.parent / "depth" / "model.onnx"), providers=["CPUExecutionProvider"])
            dw, dh = 518, 294
            x = np.asarray(im.resize((dw, dh), Image.BICUBIC), dtype=np.float32) / 255.0
            x = (x - np.array([0.485, 0.456, 0.406], dtype=np.float32)) / np.array([0.229, 0.224, 0.225], dtype=np.float32)
            depth = session.run(None, {"pixel_values": x.transpose(2, 0, 1)[None]})[0][0]
            lo, hi = np.percentile(depth, 1), np.percentile(depth, 99)
            depth = np.clip((depth - lo) / max(hi - lo, 1e-6), 0, 1)
            dim = Image.fromarray((depth * 255).astype(np.uint8), "L").resize((640, round(640 * im.height / im.width)), Image.BICUBIC)
            dim.filter(ImageFilter.GaussianBlur(4)).save(dep_p, "JPEG", quality=80)
            print("preparada", key, img_p.stat().st_size // 1024, "KB", flush=True)
        ok = all(upload(f"{d}/{key}.jpg", (OUT / d / f"{key}.jpg").read_bytes(), reg) for d in ("thumb", "dep", "img"))
        done += ok
    print(f"imagens na nuvem: {done}/{len(raws)}", flush=True)


# ------------------------------------------------------------------ áudio
def _tts(text: str, model: str, voice: str) -> bytes:
    # Só o texto a ser lido: alguns modelos leem em voz alta qualquer instrução que venha junto.
    body = json.dumps({"tts": {"text": text, "voice": voice, "model": model}}).encode()
    req = urllib.request.Request(FN, data=body, method="POST", headers={**HEAD, "Content-Type": "application/json"})
    return urllib.request.urlopen(req, timeout=170).read()


TASK = "BibliaJG-Narracao"  # tarefa diária do Windows; some sozinha quando tudo estiver narrado
SKIP = OUT / "audio_recusadas.json"
VERS = OUT / "audio_versoes.json"   # {cena: versão do áudio} (1 = <cena>.mp3; n > 1 = <cena>-v<n>.mp3)
VOZ = OUT / "voz_atual.json"        # {"voz", "serie", "amostras_em"}


def _load(path: pathlib.Path, default):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def apath(name: str, v: int) -> str:
    return f"audio/{name}.mp3" if v == 1 else f"audio/{name}-v{v}.mp3"


def _speak(text: str, voice: str, models: list, name: str, refused: dict) -> bytes | None:
    """Tenta os modelos em ordem; tira da lista os que esgotaram a cota do dia."""
    tries = 0
    while models and tries < len(TTS_MODELS) + 2:
        tries += 1
        try:
            return _tts(text, models[0], voice)
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:600]
            if e.code == 429:
                m = re.search(r"retry in ([\d.]+)s", detail)
                if "PerDay" in detail or "per day" in detail.lower() or not m:
                    print(f"  {models[0]}: cota do dia esgotada", flush=True)
                    models.pop(0)
                else:
                    wait = min(90, float(m.group(1)) + 2)
                    print(f"  {models[0]}: limite por minuto; espero {wait:.0f}s", flush=True)
                    time.sleep(wait)
            else:
                print(f"  {models[0]} falhou em {name}: {e.code} {detail[:200]}", flush=True)
                if "SAFETY" in detail or "PROHIBITED" in detail:
                    refused[name] = refused.get(name, 0) + 1
                    SKIP.write_text(json.dumps(refused, indent=0), encoding="utf-8")
                time.sleep(8)
                models.append(models.pop(0))
        except Exception as e:  # noqa: BLE001
            print(f"  {name}: {e}; espero 20s", flush=True)
            time.sleep(20)
    return None


def _to_mp3(pcm: bytes, mp3: pathlib.Path) -> bool:
    tmp = mp3.with_suffix(".tmp")
    tmp.write_bytes(pcm)
    src = ["-i", str(tmp)] if pcm[:4] == b"RIFF" else ["-f", "s16le", "-ar", "24000", "-ac", "1", "-i", str(tmp)]
    r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *src, "-af", "apad=pad_dur=0.6",
                        "-codec:a", "libmp3lame", "-b:a", "48k", "-ar", "24000", "-ac", "1", str(mp3)],
                       capture_output=True, text=True, creationflags=NO_WINDOW)
    tmp.unlink(missing_ok=True)
    if r.returncode != 0 or not mp3.exists() or mp3.stat().st_size < 20000:
        print("  ffmpeg falhou em", mp3.name, r.stderr[:200], flush=True)
        mp3.unlink(missing_ok=True)
        return False
    return True


def _chosen_voice() -> str | None:
    """Voz que o dono escolheu no app (arquivo config/voz.json na nuvem)."""
    try:
        raw = urllib.request.urlopen(PUBLIC + "config/voz.json?t=" + str(int(time.time())), timeout=30).read()
        v = json.loads(raw).get("voz")
        return v if v in VOZES else None
    except Exception:  # noqa: BLE001
        return None


def audio(limit: int) -> None:
    (OUT / "audio").mkdir(parents=True, exist_ok=True)
    (OUT / "amostras").mkdir(parents=True, exist_ok=True)
    reg = sent()
    models = list(TTS_MODELS)
    refused = _load(SKIP, {})
    vers = _load(VERS, {})
    voz = _load(VOZ, {"voz": VOZES[0], "serie": 1})
    # Áudios refeitos (ex.: sem a instrução falada) que ainda não subiram.
    for name, v in vers.items():
        f = OUT / "audio" / pathlib.Path(apath(name, v)).name
        if f.exists():
            upload(apath(name, v), f.read_bytes(), reg)

    # 1) O dono escolheu a voz no app? Se mudou, começa uma nova série (tudo será narrado de novo).
    chosen = _chosen_voice()
    if chosen and chosen != voz["voz"]:
        voz = {"voz": chosen, "serie": voz.get("serie", 1) + 1}
        VOZ.write_text(json.dumps(voz), encoding="utf-8")
        print(f"voz escolhida no app: {chosen} (série {voz['serie']})", flush=True)
    # 2) Sem escolha ainda: publica as amostras e espera até 2 dias antes de seguir com a voz padrão.
    if not chosen:
        made_s = []
        for v in VOZES:
            f = OUT / "amostras" / f"voz-{v.lower()}.mp3"
            if not f.exists():
                pcm = _speak(AMOSTRA, v, models, "amostra " + v, {})
                if pcm is None or not _to_mp3(pcm, f):
                    continue
                time.sleep(4)
            if upload(f"amostras/voz-{v.lower()}.mp3", f.read_bytes(), reg):
                made_s.append(v)
        if made_s:
            upload("amostras/vozes.json", json.dumps({"vozes": made_s, "padrao": voz["voz"]}).encode(), None)
            voz.setdefault("amostras_em", time.time())
            VOZ.write_text(json.dumps(voz), encoding="utf-8")
        if time.time() - voz.get("amostras_em", time.time()) < 2 * 86400:
            print(f"amostras de voz na nuvem: {made_s}; esperando o dono escolher no app (até 2 dias)", flush=True)
            return
    target = 1 if voz.get("serie", 1) <= 1 else voz["serie"] * 10
    made, pending = 0, 0
    for s in STORIES:
        tp = here / "texto" / f"{s['id']}.json"
        if not tp.exists():
            continue
        cenas = json.loads(tp.read_text(encoding="utf-8"))["cenas"]
        for i, text in enumerate(cenas):
            name = f"{s['id']}-{i + 1}"
            cur = vers.get(name, 1 if (OUT / "audio" / f"{name}.mp3").exists() else 0)
            if cur >= target and cur > 0:
                continue
            if refused.get(name, 0) >= len(TTS_MODELS):
                continue
            if made >= limit or not models:
                pending += 1
                continue
            new_v = max(target, 1)
            mp3 = OUT / "audio" / pathlib.Path(apath(name, new_v)).name
            pcm = _speak(f"{s['cenas'][i][5]}.\n\n{text}", voz["voz"], models, name, refused)
            if pcm is None or not _to_mp3(pcm, mp3):
                pending += 1
                continue
            if new_v != 1:
                vers[name] = new_v
                VERS.write_text(json.dumps(vers, indent=0), encoding="utf-8")
            upload(apath(name, new_v), mp3.read_bytes(), reg)
            made += 1
            print(f"narrada {name} ({mp3.stat().st_size // 1024} KB, {models[0] if models else '?'}, voz {voz['voz']})", flush=True)
            time.sleep(4)
    print(f"áudio: {made} novas narrações nesta rodada; faltam {pending}" + ("" if models else " (cota de hoje esgotada)"), flush=True)
    if pending == 0:
        # Acabou: remove a tarefa diária do Windows (se existir).
        subprocess.run(["schtasks", "/Delete", "/TN", TASK, "/F"], capture_output=True, creationflags=NO_WINDOW)


# ------------------------------------------------------------------ índice
def indice() -> None:
    reg = sent()
    vers = _load(VERS, {})
    stories, skipped = [], []
    for s in STORIES:
        tp = here / "texto" / f"{s['id']}.json"
        if not tp.exists():
            skipped.append(s["id"])
            continue
        t = json.loads(tp.read_text(encoding="utf-8"))
        if len(t["cenas"]) != len(s["cenas"]):
            skipped.append(s["id"] + " (número de cenas diferente)")
            continue
        cenas = []
        for i, (c, d) in enumerate(zip(s["cenas"], t["cenas"])):
            img, place, lat, lon, zoom, title, ref = c
            item = {"img": img, "t": title, "r": ref, "d": d.strip()}
            if lat is not None:
                item.update({"pt": place, "c": [lat, lon], "z": zoom})
            if f"img/{img}.jpg" in reg:
                item["i"] = True
            name = f"{s['id']}-{i + 1}"
            v = vers.get(name, 1)
            if apath(name, v) in reg:
                item["a"] = True if v == 1 else v  # versão > 1: o app busca <cena>-v<n>.mp3
            cenas.append(item)
        stories.append({"id": s["id"], "cat": s["cat"], "titulo": s["titulo"], "sub": s["sub"], "ref": s["ref"],
                        "cor": s["cor"], "rota": s["rota"], "resumo": t.get("resumo", ""),
                        "aplicacao": t.get("aplicacao", ""), "cenas": cenas})
    version = int(time.strftime("%y%m%d%H%M"))
    raw = json.dumps({"versao": version, "historias": stories}, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    (REPO / "assets" / "data" / "historias.json").write_bytes(raw)
    n = sum(len(s["cenas"]) for s in stories)
    ni = sum(1 for s in stories for c in s["cenas"] if c.get("i"))
    na = sum(1 for s in stories for c in s["cenas"] if c.get("a"))
    ok = upload("historias.json", raw, None)  # o índice não entra no registro de enviados
    print(f"índice versão {version}: {len(stories)} histórias, {n} cenas, {ni} com ilustração, {na} com narração; "
          f"{len(raw) // 1024} KB; nuvem: {'ok' if ok else 'FALHOU'}", flush=True)
    if skipped:
        print("sem texto:", ", ".join(skipped), flush=True)


def reconstruir() -> None:
    """Refaz o registro de enviados conferindo na nuvem cada arquivo que existe em out/."""
    base = "https://ayjsoixzroxkrnkpkkip.supabase.co/storage/v1/object/public/historias/"
    reg, missing = {}, []
    for d, ext in (("img", "jpg"), ("thumb", "jpg"), ("dep", "jpg"), ("audio", "mp3"), ("amostras", "mp3")):
        for f in sorted((OUT / d).glob("*." + ext)):
            path = f"{d}/{f.name}"
            try:
                r = urllib.request.urlopen(urllib.request.Request(base + path, method="HEAD"), timeout=30)
                if int(r.headers.get("Content-Length", "0")) == f.stat().st_size:
                    reg[path] = f.stat().st_size
                    continue
            except Exception:  # noqa: BLE001
                pass
            missing.append(path)
    SENT.write_text(json.dumps(reg, indent=0), encoding="utf-8")
    print(f"registro refeito: {len(reg)} arquivos conferidos na nuvem; faltando ou diferentes: {len(missing)} {missing[:8]}", flush=True)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "reconstruir":
        reconstruir()
        cmd = "indice"
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 400
    if cmd in ("imagens", "tudo"):
        imagens()
    if cmd in ("audio", "tudo"):
        audio(n)
    if cmd in ("indice", "tudo", "imagens", "audio"):
        indice()
    if cmd not in ("imagens", "audio", "indice", "tudo"):
        print(__doc__)
