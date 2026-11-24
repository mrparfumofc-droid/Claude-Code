import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from images import IMAGES, STYLE
here = pathlib.Path(__file__).parent
items = [{"n": i + 1, "key": k, "prompt": STYLE + v + "."} for i, (k, v) in enumerate(IMAGES.items())]
(here / "manifest.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
print(len(items), "imagens;", sum(len(i["prompt"]) for i in items) // len(items), "caracteres por prompt em média")
