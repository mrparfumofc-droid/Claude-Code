"""Corta das narrações o trecho em que a voz leu a instrução ("Narre em português do Brasil...").
Usa out/inicio_audios.json (transcrição do começo de cada áudio, com o tempo de cada palavra).
Gera out/audio/<nome>-v2.mp3 e anota a versão em out/audio_versoes.json."""
import json, pathlib, re, subprocess, unicodedata

here = pathlib.Path(__file__).parent
OUT = here / "out"
words = json.loads((OUT / "inicio_audios.json").read_text(encoding="utf-8"))
vers_p = OUT / "audio_versoes.json"
vers = json.loads(vers_p.read_text(encoding="utf-8")) if vers_p.exists() else {}


def norm(s: str) -> str:
    s = unicodedata.normalize("NFD", s.lower())
    return re.sub(r"[^a-z]", "", "".join(c for c in s if unicodedata.category(c) != "Mn"))


done = 0
for name, ws in sorted(words.items()):
    text = " ".join(norm(w) for _, w in ws[:12])
    if "contador" not in text and "portugues" not in text and "brasil" not in text:
        continue  # começa direto no título: está certo
    cut = None
    for i, (t, w) in enumerate(ws):
        if norm(w).startswith("seguir") and i + 1 < len(ws):  # "...Leia exatamente o texto a seguir:"
            cut = ws[i + 1][0]
            break
    if cut is None:
        print("NÃO ACHEI o fim da instrução em", name, "->", " ".join(w for _, w in ws[:40]))
        continue
    src = OUT / "audio" / f"{name}.mp3"
    dst = OUT / "audio" / f"{name}-v2.mp3"
    start = max(0.0, cut - 0.18)
    r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", f"{start:.2f}", "-i", str(src), "-codec:a", "libmp3lame",
                        "-b:a", "48k", "-ar", "24000", "-ac", "1", str(dst)], capture_output=True, text=True)
    if r.returncode != 0 or not dst.exists():
        print("ffmpeg falhou em", name, r.stderr[:200])
        continue
    vers[name] = 2
    done += 1
    after = " ".join(w for t, w in ws if t >= cut)[:60]
    print(f"{name}: cortei {start:.1f}s; agora começa em: {after}")
vers_p.write_text(json.dumps(vers, indent=0), encoding="utf-8")
print(done, "narrações corrigidas")
