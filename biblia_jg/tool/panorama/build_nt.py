"""Monta os dados da linha do tempo ampliada e do guia "Novo Testamento, livro por livro".

Entrada: tool/panorama/tempo/*.json (épocas e acontecimentos) e tool/panorama/nt/*.json (os 27 livros).
Saída:   assets/data/linha_tempo.json e assets/data/nt_livros.json.

Uso:  python tool/panorama/build_nt.py            (monta e confere)
      python tool/panorama/check_nt.py            (só confere o que já está em assets/data)
"""
import json
import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))
from check_nt import check  # noqa: E402

GRUPOS_NT = [
    {"id": "evangelhos", "nome": "Evangelhos", "sub": "A vida de Jesus contada por quatro testemunhas", "cor": "EF6C00"},
    {"id": "atos", "nome": "Atos", "sub": "A história da igreja primitiva", "cor": "1E88E5"},
    {"id": "paulo", "nome": "Cartas de Paulo", "sub": "A nove igrejas e a três colaboradores", "cor": "5E35B1"},
    {"id": "gerais", "nome": "Hebreus e cartas gerais", "sub": "Tiago, Pedro, João, Judas e o autor de Hebreus", "cor": "00897B"},
    {"id": "apocalipse", "nome": "Apocalipse", "sub": "A revelação de Jesus Cristo", "cor": "C62828"},
]
GRUPOS_TEMPO = [
    {"id": "at", "nome": "Antigo Testamento"},
    {"id": "nt", "nome": "Novo Testamento"},
    {"id": "igreja", "nome": "História da igreja"},
]


def _load(folder: str) -> list:
    out = []
    for f in sorted((HERE / folder).glob("*.json")):
        out.extend(json.loads(f.read_text(encoding="utf-8")))
    return out


def main() -> int:
    versao = int(time.strftime("%y%m%d%H%M"))
    eras = _load("tempo")
    books = sorted(_load("nt"), key=lambda b: b["n"])
    tempo = {"versao": versao, "grupos": GRUPOS_TEMPO, "epocas": eras}
    nt = {"versao": versao, "grupos": GRUPOS_NT, "livros": books}
    data = REPO / "assets" / "data"
    (data / "linha_tempo.json").write_text(json.dumps(tempo, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (data / "nt_livros.json").write_text(json.dumps(nt, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"linha_tempo.json: {len(eras)} épocas, {sum(len(e['eventos']) for e in eras)} acontecimentos")
    print(f"nt_livros.json: {len(books)} livros, {sum(len(b['partes']) for b in books)} partes")
    return check()


if __name__ == "__main__":
    sys.exit(main())
