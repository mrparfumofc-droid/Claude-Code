#!/usr/bin/env python3
"""Gera os dados extras usados nas versões da Bíblia do app:

* tool/enrichment/headings.json  — títulos de seção por livro/versículo (en, pt, es),
  extraídos da Berean Standard Bible (domínio público) e traduzidos com o Gemini.
* tool/enrichment/words_of_jesus.json — trechos com as palavras de Jesus por versículo
  (índices de palavras na BSB + total de palavras do versículo).

Roda uma vez (o resultado fica no repositório). Precisa de GEMINI_API_KEY no ambiente
para traduzir os títulos.

Uso: GEMINI_API_KEY=... python3 tool/build_enrichment.py [--cache PASTA]
"""
import argparse
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "tool" / "enrichment"
SRC = "https://raw.githubusercontent.com/LetsChurch/bsb-enriched/main/"

USX_CODES = (
    "GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA PRO "
    "ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC MAL MAT "
    "MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE "
    "2PE 1JN 2JN 3JN JUD REV"
).split()


def fetch(url: str, cache: pathlib.Path | None, name: str, attempts: int = 6) -> str:
    if cache:
        f = cache / name
        if f.exists():
            return f.read_text(encoding="utf-8")
    for i in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                text = r.read().decode("utf-8")
            if cache:
                cache.mkdir(parents=True, exist_ok=True)
                (cache / name).write_text(text, encoding="utf-8")
            return text
        except (urllib.error.URLError, TimeoutError) as e:
            if i == attempts - 1:
                raise
            time.sleep(5 * 2**i)
            print(f"  nova tentativa ({e})", file=sys.stderr)
    raise RuntimeError


_TAG = re.compile(r"<[^>]+>")
_NOTE = re.compile(r"<note\b.*?</note>", re.S)
_VERSE_START = re.compile(r'<verse\b[^>]*?\bsid="([^"]+)"[^>]*/>')
_VERSE_END = re.compile(r'<verse\b[^>]*?\beid="([^"]+)"[^>]*/>')
_HEADING = re.compile(r'<para style="s1"[^>]*>(.*?)</para>', re.S)


def parse_usx(usx: str):
    """Retorna (títulos {"c:v": título}, contagem de palavras {"c:v": n})."""
    usx = _NOTE.sub("", usx)
    headings: dict[str, str] = {}
    words: dict[str, int] = {}
    pending: list[str] = []
    pos = 0
    tokens = re.compile(
        r'<para style="s1"[^>]*>.*?</para>|<verse\b[^>]*?\bsid="[^"]+"[^>]*/>', re.S
    )
    for m in tokens.finditer(usx):
        tok = m.group(0)
        if tok.startswith("<para"):
            title = _TAG.sub("", _HEADING.match(tok).group(1)).strip()
            if title:
                pending.append(title)
        else:
            sid = _VERSE_START.match(tok).group(1)
            cv = sid.split(" ", 1)[1]
            if pending:
                headings[cv] = " — ".join(pending)
                pending = []
        pos = m.end()
    for m in _VERSE_START.finditer(usx):
        sid = m.group(1)
        end = _VERSE_END.search(usx, m.end())
        if not end:
            continue
        text = _TAG.sub("", usx[m.end():end.start()])
        words[sid.split(" ", 1)[1]] = len(text.split())
    return headings, words


def translate(titles: list[str], key: str) -> list[dict]:
    """Traduz uma lista de títulos para pt-BR e es. Retorna [{"pt":..,"es":..}]."""
    prompt = (
        "Traduza estes títulos de seção da Bíblia (inglês) para português do Brasil e "
        "espanhol, no estilo dos títulos das Bíblias evangélicas em cada idioma. Use os "
        "nomes próprios bíblicos na forma tradicional de cada idioma (ex.: Jesus, Moisés, "
        "Davi / Moisés, David). Responda só com um array JSON com o mesmo número de itens, "
        'na mesma ordem, cada item no formato {"pt": "...", "es": "..."}.\n\n'
        + json.dumps(titles, ensure_ascii=False)
    )
    body = json.dumps({
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {"responseMimeType": "application/json", "maxOutputTokens": 65536},
    }).encode()
    for i in range(5):
        req = urllib.request.Request(
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent",
            data=body,
            headers={"Content-Type": "application/json", "x-goog-api-key": key},
        )
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                data = json.loads(r.read())
            text = "".join(
                p.get("text", "") for p in data["candidates"][0]["content"]["parts"]
                if not p.get("thought")
            )
            out = json.loads(text)
            if len(out) == len(titles) and all("pt" in o and "es" in o for o in out):
                return out
            print(f"  tradução com {len(out)} itens (esperado {len(titles)}), repetindo", file=sys.stderr)
        except Exception as e:  # noqa: BLE001 - qualquer falha: tenta de novo
            print(f"  erro na tradução ({e}), repetindo", file=sys.stderr)
        time.sleep(5 * (i + 1))
    raise RuntimeError("não foi possível traduzir os títulos")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", type=pathlib.Path)
    args = ap.parse_args()
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        print("Defina GEMINI_API_KEY.", file=sys.stderr)
        return 1
    OUT.mkdir(parents=True, exist_ok=True)

    # Traduções já feitas são reaproveitadas.
    out_headings = OUT / "headings.json"
    previous = json.loads(out_headings.read_text()) if out_headings.exists() else {}

    all_words: dict[str, dict[str, int]] = {}
    headings: dict[str, dict[str, dict[str, str]]] = {}
    for code in USX_CODES:
        usx = fetch(f"{SRC}bsb/USX_1/{code}.usx", args.cache, f"{code}.usx")
        h, w = parse_usx(usx)
        all_words[code] = w
        old = previous.get(code, {})
        if old and set(old) == set(h) and all(old[k].get("en") == h[k] for k in h):
            headings[code] = old
            print(f"{code}: {len(h)} títulos (reaproveitados)")
            continue
        tr = translate(list(h.values()), key) if h else []
        headings[code] = {
            cv: {"en": en, "pt": t["pt"].strip(), "es": t["es"].strip()}
            for (cv, en), t in zip(h.items(), tr)
        }
        print(f"{code}: {len(h)} títulos traduzidos")
        out_headings.write_text(json.dumps(headings | {k: v for k, v in previous.items() if k not in headings}, ensure_ascii=False, indent=0), encoding="utf-8")

    out_headings.write_text(json.dumps(headings, ensure_ascii=False, indent=0), encoding="utf-8")

    woj: dict[str, dict[str, dict]] = {}
    for line in fetch(f"{SRC}words_of_jesus.jsonl", args.cache, "words_of_jesus.jsonl").splitlines():
        if not line.strip():
            continue
        e = json.loads(line)
        code, cv = e["ref"].split(" ", 1)
        total = all_words.get(code, {}).get(cv)
        if not total:
            continue
        runs = [r for r in e["runs"] if 0 <= r[0] < r[1] <= total]
        if runs:
            woj.setdefault(code, {})[cv] = {"n": total, "runs": runs}
    (OUT / "words_of_jesus.json").write_text(json.dumps(woj, separators=(",", ":")), encoding="utf-8")
    print(f"palavras de Jesus: {sum(len(v) for v in woj.values())} versículos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
