#!/usr/bin/env python3
"""Traduz os dicionários bíblicos de domínio público (Easton, Hitchcock, Torrey,
Smith — dataset JWBickel/BibleDictionaries) para o português, usando a Edge
Function temporária `translate-dict` (modelos Gemma, cota grátis própria).

Retoma de onde parou: cada verbete pronto vai para PASTA/pt/<dic>.jsonl.
Uso: python tool/translate_dictionaries.py PASTA [--workers 3] [--publicar]

O dicionário é publicado COMPLETO: os verbetes já traduzidos em português e os que faltam no
original em inglês (marcados com "en": true). No app, o verbete em inglês pode ser traduzido na
hora pela IA; conforme a tradução avança aqui, uma nova versão é publicada.
"""
import argparse
import concurrent.futures as cf
import json
import pathlib
import re
import sys
import threading
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
FN = "https://ayjsoixzroxkrnkpkkip.supabase.co/functions/v1/translate-dict"
DICTS = [  # (código, arquivo, nome). O dono pediu só o Easton, completo (24/11/2026).
    ("easton", "Easton's Bible Dictionary.jsonl", "Dicionário Bíblico Easton"),
]
ABOUT = {
    "easton": "Dicionário bíblico geral de M. G. Easton (1897), domínio público. Os verbetes ainda não traduzidos "
              "aparecem em inglês e podem ser traduzidos na hora.",
}
MODELS = ["gemma-4-26b-a4b-it", "gemma-4-31b-it"]


def publish_all(base: pathlib.Path) -> None:
    """Publica no bucket público "dicionarios" o dicionário completo (traduzido + o que falta em inglês)."""
    index = []
    for code, fname, title in DICTS:
        src = [json.loads(l) for l in (base / "en" / fname).read_text(encoding="utf-8").splitlines() if l.strip()]
        done = {}
        path = base / "pt" / f"{code}.jsonl"
        if path.exists():
            for l in path.read_text(encoding="utf-8").splitlines():
                if l.strip():
                    r = json.loads(l)
                    done[r["n"]] = r
        items = []
        for n, row in enumerate(src):
            if n in done and done[n].get("texto"):
                items.append({"t": done[n]["termo"], "e": done[n]["en"], "x": done[n]["texto"]})
            else:
                text = "\n\n".join(d.strip() for d in row.get("definitions", []) if d and d.strip())
                if text:
                    items.append({"t": row["term"], "e": row["term"], "x": text, "en": True})
        _publish(f"{code}.json", json.dumps(items, ensure_ascii=False, separators=(",", ":")))
        index.append({"code": code, "name": title, "about": ABOUT[code], "count": len(items),
                      "version": f"completo-{len(done)}"})
        print(f"publicado: {code} com {len(items)} verbetes ({len(done)} em português)", flush=True)
    if index:
        _publish("index.json", json.dumps(index, ensure_ascii=False))


def _publish(path: str, content: str) -> None:
    body = json.dumps({"publish": {"path": path, "content": content}}).encode()
    for i in range(4):
        try:
            urllib.request.urlopen(urllib.request.Request(FN, data=body, headers=HEAD, method="POST"), timeout=120).read()
            return
        except Exception as e:  # noqa: BLE001
            print(f"  publicar {path} falhou ({e})", file=sys.stderr, flush=True)
            time.sleep(10 * (i + 1))
MAX_CHARS = 2400

svc = (ROOT / "lib/services/ai_service.dart").read_text(encoding="utf-8")
ANON = re.search(r"'(eyJ[^']+)'", svc).group(1)
APPKEY = re.search(r"const appKey =\s*'([^']+)'", svc).group(1)
HEAD = {"Authorization": "Bearer " + ANON, "apikey": ANON, "x-app-key": APPKEY, "Content-Type": "application/json"}
lock = threading.Lock()


def split(text: str) -> list[str]:
    """Divide textos longos em partes de até MAX_CHARS, em parágrafos/frases."""
    if len(text) <= MAX_CHARS:
        return [text]
    parts, cur = [], ""
    for para in re.split(r"(?<=\n\n)|(?<=[.;:]) ", text):
        if len(cur) + len(para) > MAX_CHARS and cur:
            parts.append(cur.strip())
            cur = ""
        cur += para if para.endswith("\n\n") else para + " "
    if cur.strip():
        parts.append(cur.strip())
    return parts


def call(items: list[dict], attempt: int) -> list[dict]:
    model = MODELS[attempt % len(MODELS)]
    body = json.dumps({"items": items, "model": model}).encode()
    req = urllib.request.Request(FN, data=body, headers=HEAD, method="POST")
    try:
        res = json.loads(urllib.request.urlopen(req, timeout=170).read())
    except urllib.error.HTTPError as e:
        res = json.loads(e.read() or b"{}")
    if "out" not in res:
        raise RuntimeError(f"{model}: {res.get('error')} {str(res.get('detail') or res.get('raw') or '')[:160]}")
    out = {str(o.get("id")): o for o in res["out"] if isinstance(o, dict)}
    missing = [i["id"] for i in items if i["id"] not in out]
    if missing:
        raise RuntimeError(f"{model}: faltaram {missing}")
    return [out[i["id"]] for i in items]


def translate(items: list[dict]) -> list[dict]:
    for attempt in range(12):
        try:
            return call(items, attempt)
        except Exception as e:  # noqa: BLE001
            wait = min(240, 15 * (attempt + 1))
            msg = str(e)
            if "429" in msg or "quota" in msg.lower():
                wait = 90
            print(f"  tentativa {attempt + 1} falhou ({msg[:120]}); espero {wait}s", file=sys.stderr, flush=True)
            time.sleep(wait)
    raise RuntimeError("desisti deste lote")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("base")
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--publicar", action="store_true", help="só publica o que já existe e sai")
    a = ap.parse_args()
    base = pathlib.Path(a.base)
    if a.publicar:
        publish_all(base)
        return 0
    (base / "pt").mkdir(parents=True, exist_ok=True)
    for code, fname, title in DICTS:
        src = [json.loads(l) for l in (base / "en" / fname).read_text(encoding="utf-8").splitlines() if l.strip()]
        out_path = base / "pt" / f"{code}.jsonl"
        done = set()
        if out_path.exists():
            for l in out_path.read_text(encoding="utf-8").splitlines():
                if l.strip():
                    done.add(json.loads(l)["id"])
        # Lotes: vários verbetes curtos juntos; verbetes longos em partes.
        batches, cur, size = [], [], 0
        for n, row in enumerate(src):
            eid = f"{code}{n:05d}"
            if eid in done:
                continue
            text = "\n\n".join(d.strip() for d in row.get("definitions", []) if d and d.strip())
            parts = split(text) if text else [""]
            if len(parts) > 1:
                batches.append([{"id": f"{eid}#{k}", "term": row["term"], "text": p, "_eid": eid, "_n": n}
                                for k, p in enumerate(parts)])
                continue
            item = {"id": eid, "term": row["term"], "text": parts[0], "_eid": eid, "_n": n}
            if size + len(parts[0]) > MAX_CHARS or len(cur) >= 25:
                batches.append(cur)
                cur, size = [], 0
            cur.append(item)
            size += len(parts[0])
        if cur:
            batches.append(cur)
        total = len(src)
        print(f"{title}: {len(done)}/{total} prontos, {len(batches)} lotes a fazer", flush=True)

        def work(batch: list[dict]) -> int:
            # Partes de um verbete longo vão uma por chamada (cabe no tempo do servidor).
            if "#" in batch[0]["id"]:
                res = [translate([{k: v for k, v in it.items() if not k.startswith("_")}])[0] for it in batch]
                term = res[0].get("termo") or batch[0]["term"]
                rows = [{"id": batch[0]["_eid"], "n": batch[0]["_n"], "en": batch[0]["term"], "termo": term,
                         "texto": "\n\n".join(r.get("texto", "") for r in res)}]
            else:
                res = translate([{k: v for k, v in it.items() if not k.startswith("_")} for it in batch])
                rows = [{"id": it["_eid"], "n": it["_n"], "en": it["term"], "termo": r.get("termo") or it["term"],
                         "texto": r.get("texto", "")} for it, r in zip(batch, res)]
            with lock, out_path.open("a", encoding="utf-8") as f:
                for r in rows:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")
            return len(rows)

        count = len(done)
        last_pub = count
        with cf.ThreadPoolExecutor(a.workers) as ex:
            for fut in cf.as_completed([ex.submit(work, b) for b in batches]):
                try:
                    count += fut.result()
                except Exception as e:  # noqa: BLE001
                    print(f"  lote perdido: {e}", file=sys.stderr, flush=True)
                if count % 50 < 25:
                    print(f"{title}: {count}/{total}", flush=True)
                if count - last_pub >= 300:
                    last_pub = count
                    publish_all(base)
        print(f"{title}: terminado ({count}/{total})", flush=True)
        publish_all(base)
    return 0


if __name__ == "__main__":
    sys.exit(main())
