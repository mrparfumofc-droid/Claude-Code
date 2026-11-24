#!/usr/bin/env python3
"""Gera assets/data/xrefs.json a partir das referências cruzadas do OpenBible.info
(licença CC-BY: https://www.openbible.info/labs/cross-references/).

Formato: {"livro:cap:vers": "alvo;alvo;..."} com no máximo MAX_PER_VERSE alvos por
versículo, ordenados por votos. Cada alvo é "livro:cap:vers" ou "livro:cap:vers-versFinal"
(livro = índice 0..65).

Uso: python3 tool/build_xrefs.py caminho/cross_references.txt
"""
import json
import pathlib
import sys

OSIS = (
    "Gen Exod Lev Num Deut Josh Judg Ruth 1Sam 2Sam 1Kgs 2Kgs 1Chr 2Chr Ezra Neh Esth Job Ps "
    "Prov Eccl Song Isa Jer Lam Ezek Dan Hos Joel Amos Obad Jonah Mic Nah Hab Zeph Hag Zech "
    "Mal Matt Mark Luke John Acts Rom 1Cor 2Cor Gal Eph Phil Col 1Thess 2Thess 1Tim 2Tim "
    "Titus Phlm Heb Jas 1Pet 2Pet 1John 2John 3John Jude Rev"
).split()
INDEX = {b: i for i, b in enumerate(OSIS)}
MAX_PER_VERSE = 15
MIN_VOTES = 1

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "data" / "xrefs.json"


def ref(osis: str) -> tuple[int, int, int] | None:
    parts = osis.split(".")
    if len(parts) != 3 or parts[0] not in INDEX:
        return None
    return INDEX[parts[0]], int(parts[1]), int(parts[2])


def main() -> int:
    src = pathlib.Path(sys.argv[1])
    links: dict[str, list[tuple[int, str]]] = {}
    for line in src.read_text(encoding="utf-8").splitlines()[1:]:
        cols = line.split("\t")
        if len(cols) < 3:
            continue
        a = ref(cols[0])
        votes = int(cols[2])
        if a is None or votes < MIN_VOTES:
            continue
        to = cols[1].split("-")
        b = ref(to[0])
        if b is None:
            continue
        target = f"{b[0]}:{b[1]}:{b[2]}"
        if len(to) == 2:
            e = ref(to[1])
            if e and e[0] == b[0] and e[1] == b[1] and e[2] > b[2]:
                target += f"-{e[2]}"
        links.setdefault(f"{a[0]}:{a[1]}:{a[2]}", []).append((votes, target))
    out = {
        k: ";".join(t for _, t in sorted(v, key=lambda x: -x[0])[:MAX_PER_VERSE])
        for k, v in links.items()
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, separators=(",", ":")), encoding="utf-8")
    print(f"{len(out)} versículos, {sum(s.count(';') + 1 for s in out.values())} ligações, {OUT.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
