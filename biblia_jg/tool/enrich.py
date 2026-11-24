"""Aplica títulos de seção e marcação das palavras de Jesus aos versículos.

Os dados vêm de tool/enrichment/ (gerados por build_enrichment.py a partir da BSB).
A marcação das palavras de Jesus vem com índices de palavras da BSB (inglês); aqui ela é
levada para o texto de cada versão pela posição relativa no versículo, ajustando o início e
o fim aos sinais de fala mais próximos (dois-pontos, travessão, aspas).
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent
DATA = ROOT / "enrichment"

USX_CODES = (
    "GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA PRO "
    "ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC MAL MAT "
    "MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE "
    "2PE 1JN 2JN 3JN JUD REV"
).split()

_WORD = re.compile(r"\S+")
_OPENERS = ("—", "–", '"', "“", "«", "'", "‘")
_CLOSERS = ('"', "”", "»", "'", "’")
_SPEECH_VERB = re.compile(
    r"\b(disse|diz|dizia|dizendo|respondeu|respondendo|falou|perguntou|clamou|ordenou|"
    r"said|says|saying|answered|replied|asked|dijo|dice|diciendo|respondió|respondiendo)\b",
    re.I,
)
_WINDOW = 4


def load():
    headings = json.loads((DATA / "headings.json").read_text(encoding="utf-8")) if (DATA / "headings.json").exists() else {}
    woj = json.loads((DATA / "words_of_jesus.json").read_text(encoding="utf-8")) if (DATA / "words_of_jesus.json").exists() else {}
    return headings, woj


def _nearest(candidates, target):
    return min(candidates, key=lambda c: abs(c - target)) if candidates else None


def mark_jesus(text: str, n: int, runs: list[list[int]]) -> str:
    """Insere <J>...</J> em [text] para os trechos [runs] (índices de palavras num versículo de [n] palavras)."""
    spans = [m.span() for m in _WORD.finditer(text)]
    nw = len(spans)
    if nw == 0 or n <= 0:
        return text
    words = [text[a:b] for a, b in spans]
    marks: list[tuple[int, int]] = []
    for s, e in runs:
        a = 0 if s == 0 else round(s / n * nw)
        b = nw if e >= n else round(e / n * nw)
        if s > 0:
            starts = [
                j + 1 for j in range(max(0, a - _WINDOW - 1), min(nw, a + _WINDOW))
                if words[j].endswith(":")
            ] + [
                j for j in range(max(0, a - _WINDOW), min(nw, a + _WINDOW + 1))
                if words[j].startswith(_OPENERS)
            ]
            a = _nearest(starts, a) if starts else a
        else:
            # Versículo que na BSB começa com a fala, mas aqui começa com "Jesus disse:".
            colon = next((j for j, w in enumerate(words) if w.endswith(":")), None)
            if colon is not None and colon < nw * 0.5 and _SPEECH_VERB.search(" ".join(words[: colon + 1])):
                a = colon + 1
        if e < n:
            ends = [
                j + 1 for j in range(max(0, b - _WINDOW - 1), min(nw, b + _WINDOW))
                if words[j].endswith(_CLOSERS) or words[j].rstrip("”\"'’»").endswith((".", "!", "?", ";"))
            ]
            b = _nearest(ends, b) if ends else b
        a, b = max(0, min(a, nw)), max(0, min(b, nw))
        if b > a:
            marks.append((a, b))
    if not marks:
        return text
    marks.sort()
    merged = [list(marks[0])]
    for a, b in marks[1:]:
        if a <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], b)
        else:
            merged.append([a, b])
    out, pos = [], 0
    for a, b in merged:
        start, end = spans[a][0], spans[b - 1][1]
        out.append(text[pos:start])
        out.append("<J>" + text[start:end] + "</J>")
        pos = end
    out.append(text[pos:])
    return "".join(out)


def enrich_books(books: list[dict], lang: str, headings: dict, woj: dict) -> None:
    """Altera [books] (formato do app) adicionando "titles" e a marcação <J>."""
    for i, book in enumerate(books):
        if i >= len(USX_CODES):
            break
        code = USX_CODES[i]
        chapters = book["chapters"]

        def exists(cv: str) -> bool:
            c, v = (int(x) for x in cv.split(":"))
            return 1 <= c <= len(chapters) and 1 <= v <= len(chapters[c - 1])

        titles = {
            cv: h.get(lang) or h.get("en")
            for cv, h in headings.get(code, {}).items()
            if exists(cv) and (h.get(lang) or h.get("en"))
        }
        if titles:
            book["titles"] = titles
        for cv, info in woj.get(code, {}).items():
            if not exists(cv):
                continue
            c, v = (int(x) for x in cv.split(":"))
            chapters[c - 1][v - 1] = mark_jesus(chapters[c - 1][v - 1], info["n"], info["runs"])
