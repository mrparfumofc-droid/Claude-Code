"""Confere o assets/data/linhagens.json já gerado, sem refazê-lo: referências bíblicas (capítulo e versículo
existem numa Bíblia do app), ligações, sobreposição de nós, tamanho dos passos, ilustrações e retratos.

Uso:  python tool/panorama/check_linhagens.py      (sai com código 1 se houver problema)
"""
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from build_linhagens import REPO, confere  # noqa: E402

quadros = json.loads((REPO / "assets/data/linhagens.json").read_text(encoding="utf-8"))["quadros"]
arte = json.loads((HERE / "arte_linhagens.json").read_text(encoding="utf-8"))
sys.exit(0 if confere(quadros, arte) else 1)
