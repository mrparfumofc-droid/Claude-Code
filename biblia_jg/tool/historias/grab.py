"""Uso: python grab.py chave1 chave2 ...   (na ordem em que os downloads foram clicados)
Move os Gemini_Generated_Image_* NOVOS (baixados nesta sessão) da pasta Downloads para raw/<chave>.<ext>.
--iniciar: marca o começo de uma sessão de downloads (rodar antes da 1ª rodada).
Sem argumentos: mostra o que falta.  --limpar: tira da frente os downloads novos que sobraram.
Nunca toca nos arquivos antigos do dono (anteriores ao início desta sessão)."""
import datetime, json, pathlib, shutil, sys, time
here = pathlib.Path(__file__).parent
dl = pathlib.Path.home() / "Downloads"
raw = here / "raw"
MARK = here / ".inicio"
if sys.argv[1:2] == ["--iniciar"]:
    MARK.write_text(str(time.time()))
    print("início marcado: só os downloads feitos a partir de agora serão usados")
    sys.argv = sys.argv[:1]
# Só valem os downloads feitos depois do último "--iniciar" (os antigos são do dono).
START = float(MARK.read_text()) if MARK.exists() else time.time()
man = json.loads((here / "manifest.json").read_text(encoding="utf-8"))
valid = {m["key"] for m in man}
keys = sys.argv[1:]


def fresh():
    return sorted([p for p in dl.glob("Gemini_Generated_Image_*")
                   if p.suffix.lower() in (".jpeg", ".jpg", ".png", ".webp") and p.stat().st_mtime > START],
                  key=lambda p: p.stat().st_mtime)


if keys[:1] == ["--limpar"]:
    (raw / "_sobras").mkdir(exist_ok=True)
    for p in fresh():
        shutil.move(str(p), str(raw / "_sobras" / p.name))
    print("downloads novos soltos foram para raw/_sobras")
    keys = []
if keys:
    bad = [k for k in keys if k not in valid]
    if bad:
        print("ERRO: chave desconhecida:", bad)
        sys.exit(1)
    time.sleep(2)
    new = fresh()
    if len(new) != len(keys):
        print(f"ERRO: {len(new)} arquivo(s) novo(s) para {len(keys)} chave(s). Nada foi movido.")
        for p in new:
            print("  ", p.name, time.strftime("%H:%M:%S", time.localtime(p.stat().st_mtime)), p.stat().st_size // 1024, "KB")
        print("Para tirar da frente os downloads soltos e repetir: python grab.py --limpar")
        sys.exit(1)
    for k, p in zip(keys, new):
        for old in raw.glob(k + ".*"):
            old.unlink()
        shutil.move(str(p), str(raw / f"{k}{p.suffix}"))
        print("ok", k)
done = {p.stem for p in raw.iterdir() if p.is_file()}
missing = [m["key"] for m in man if m["key"] not in done]
print(f"prontas {len(done & valid)}/{len(man)}; faltam {len(missing)}; próximas: {' '.join(missing[:6])}")
