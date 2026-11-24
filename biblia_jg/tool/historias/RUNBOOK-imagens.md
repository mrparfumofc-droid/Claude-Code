# Runbook: gerar as ilustrações que faltam (Histórias bíblicas do app Bíblia JG)

Objetivo: gerar no Google Gemini (Chrome do dono, extensão Claude in Chrome, conta Pro já logada) as
ilustrações que ainda faltam, guardar cada download com o nome certo e publicar na nuvem.
O dono (Joabe) pediu essas ilustrações e autorizou gerar pelo Gemini no navegador. Responder a ele sempre
em português do Brasil, curto.

Pasta de trabalho: `D:\Claude Code\mapas-biblia\historias`
Python: `"/c/Users/Joabe Gonçalves/AppData/Local/Programs/Python/Python312/python.exe" -X utf8` (ferramenta Bash).

## Regras que não podem ser quebradas
- O plano do Gemini tem limite de uso por janela (~40 imagens a cada ~2 h). Quando o Gemini responder que o
  limite foi atingido ("I can create more images as soon as your limit resets" / "Limite atingido"), PARE.
  Nunca clicar em "Ativar uso extra", "Faça upgrade", comprar créditos ou mudar configurações.
- Nunca apagar, mover ou renomear os arquivos `Gemini_Generated_Image_*` antigos da pasta Downloads: são
  do dono. O `grab.py` só mexe nos baixados nesta tarefa (ele filtra pela data).
- Só usar abas do grupo desta sessão em gemini.google.com. Não tocar em outros sites nem nas conversas antigas.
- Um mapeamento errado (imagem com o nome de outra cena) é pior que uma imagem faltando: na dúvida, não baixe.
- Não tirar screenshots, a não ser travado (use scale 0.4).

## Passo a passo
1. `python grab.py` (sem argumentos) mostra quantas estão prontas e as próximas chaves que faltam.
   Se não falta nenhuma, vá direto ao passo 5.
   Antes da primeira rodada rode `python grab.py --iniciar`: ele marca o começo desta sessão e passa a
   ignorar qualquer download anterior.
2. `cenas.txt` tem uma linha por imagem: `chave | descrição da cena` (em inglês), na ordem de prioridade.
   Leia em blocos grandes. Gere só as chaves que faltam, nessa ordem.
3. Carregue as ferramentas do Chrome numa única chamada ToolSearch:
   `select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__browser_batch,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__javascript_tool,mcp__claude-in-chrome__tabs_create_mcp,mcp__claude-in-chrome__tabs_close_mcp`
   Chame `tabs_context_mcp` (createIfEmpty true), crie abas até ter 4 e navegue as 4 para
   `https://gemini.google.com/app` (conversa nova em cada). Espere 4 s.
   Confira com javascript_tool: `(localStorage.getItem('__jg_style')||'').length` deve dar ~490.
   Se der 0, grave o estilo: rode `python -c "from images import STYLE; print(STYLE)"` e faça
   `localStorage.setItem('__jg_style', "<esse texto>")`.
   Se a página mostrar "Limite atingido" junto à caixa de texto, pare e vá ao passo 5.
4. Rodadas. Cada rodada = UMA chamada `browser_batch` + UMA chamada `grab.py`. Guarde, por aba, N = número
   de imagens já geradas na conversa daquela aba (0 depois de navegar).
   No batch, nesta ordem (SCENE = descrição exata da cena, que nunca tem aspas duplas; `__N__` = N+1 da aba):
   a. Para cada aba:
      - javascript_tool: `const e=document.querySelector('.ql-editor'); e.focus(); document.execCommand('insertText', false, localStorage.getItem('__jg_style') + "SCENE"); e.innerText.length`
      - computer: `{"action":"key","text":"Return","action_summary":"Sends the prompt to Gemini"}`
   b. Cinco `computer` wait de 10 s (50 s no total).
   c. Para cada aba, na mesma ordem:
      - javascript_tool: `const N=__N__; const bs=[...document.querySelectorAll('button[aria-label*="Baixar imagem"]')]; const imgs=document.querySelectorAll('img.image.loaded').length; const lim=/limit resets|Limite atingido/i.test(document.body.innerText); let ok=false; if(bs.length===N && imgs===N){const b=bs[N-1]; b.scrollIntoView({block:'center'}); b.focus(); ok=true;} else if(document.activeElement){document.activeElement.blur();} JSON.stringify({ok, lim, buttons:bs.length, imgs, turns:document.querySelectorAll('model-response').length})`
      - computer: `{"action":"key","text":"Return","action_summary":"Activates the focused download button"}` (com ok:false nada está focado e a tecla não faz nada)
      - computer: wait 5 s
   Depois: para as abas com `"ok":true`, rode `python grab.py <chaves dessas abas, na ordem das abas>` e some 1 ao N delas.
   - `"ok":false` com imagem ainda sendo gerada: num batch pequeno só daquela aba, dois waits de 10 s, o mesmo
     JS, Return, wait 5 s; se ok, `grab.py` só com aquela chave.
   - `"lim":true` em todas as abas: limite atingido, pare e vá ao passo 5.
   - Resposta só em texto (turns cresceu, imgs não), sem ser limite: tente a cena mais uma vez com a descrição
     suavizada (sem violência, armas, medo ou nudez). Se falhar de novo, acrescente a chave em `falhas.txt` e siga.
   - `grab.py` reclamou da contagem: espere 10 s e rode de novo; se continuar, `python grab.py --limpar` e
     gere de novo as chaves da rodada.
   - A cada 8 imagens numa aba, comece conversa nova nela (navigate para `https://gemini.google.com/app`, N = 0).
5. Publicar: `python midia.py imagens` (prepara tamanhos e profundidade, envia para a nuvem e refaz o índice;
   pode levar alguns minutos). Confira a última linha: "N com ilustração".
6. Feche as abas que você criou (tabs_close_mcp) e responda em português: quantas ilustrações novas, quantas
   faltam (`python grab.py`), se parou por limite e o que estiver em `falhas.txt`.
