"""Rotina diária da voz do app (Algieba), com a cota grátis do dia dividida nesta ordem:

  1) capítulos da Bíblia que o leitor pediu para ouvir (leitura.py), mais os seguintes;
  2) narrações do Panorama, das árvores e do guia do Novo Testamento (narr.py);
  3) cenas das histórias ilustradas (midia.py audio), e o índice das histórias.

  python voz.py          rodada completa (tarefa do Windows "BibliaJG-Narracao", todo dia às 06:10)
  python voz.py fila     só as filas (capítulos e textos que o app pediu) (tarefa "BibliaJG-Leitura", de hora em hora)
"""
import pathlib, sys, time

here = pathlib.Path(__file__).parent
sys.path.insert(0, str(here))
import midia  # noqa: E402  (redireciona a saída para midia.log quando roda sem janela)
import leitura  # noqa: E402
import narr  # noqa: E402

if __name__ == "__main__":
    so_fila = len(sys.argv) > 1 and sys.argv[1] == "fila"
    models = list(midia.TTS_MODELS)
    try:
        leitura.rodar(8 if so_fila else 14, models)
    except Exception as e:  # noqa: BLE001
        print("leitura falhou:", e, flush=True)
    try:
        narr.rodar(6 if so_fila else 16, models)
    except Exception as e:  # noqa: BLE001
        print("narrações falharam:", e, flush=True)
    if not so_fila:
        try:
            midia.audio(400, models)
            midia.indice()
        except Exception as e:  # noqa: BLE001
            print("histórias falharam:", e, flush=True)
        print(time.strftime("fim da rodada %d/%m %H:%M"), flush=True)
