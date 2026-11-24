# Bíblia JG: resumo para continuar o trabalho

Atualizado em 24/11/2026. Branch de trabalho: `ccr-bd8c0120-93hpn2` (repo `mrparfumofc-droid/Claude-Code`, pasta `biblia_jg/`).

## O que é
App Flutter de Bíblia para tablet Android, de uso pessoal do dono (JG Company). Interface em português.

## Estado atual (build 17, publicado e assinado)
- **Leitura:** layout de tablet com livros à esquerda e texto à direita, todas as configurações de leitura, cor da página independente do modo noturno (que vale só para o app), seleção de versículo sublinhada com fundo opaco.
- **22 versões.** As 18 em português vêm de `damarals/biblias` (releases). Ave-Maria, KJV, NIV e RVR1960 vêm de `thiagobodruk/bible`. São baixadas na hora do build por `tool/fetch_bibles.py`, com SHA-256 conferido e cache no Actions. Os textos **não** ficam no repositório.
- **Títulos de seção** (3.016) e **palavras de Jesus** (2.045 versículos) a partir da Berean Standard Bible, que é domínio público. Ficam em `tool/enrichment/` e são aplicados por `tool/enrich.py`. Os títulos foram traduzidos com o Gemini por `tool/build_enrichment.py`.
- **Ações do versículo:** marcar com cores, favoritar, anotar, copiar, compartilhar, Estudo bíblico (IA), Imagem (editor de cartão), Ouvir (TTS que acompanha o versículo lido), Referências (OpenBible, CC-BY, em `assets/data/xrefs.json`).
- **Menu:** Assistente IA, Planos de leitura (9), Devocional diário (IA, guardado por dia), Histórias bíblicas (56, IA), Perguntas bíblicas (IA, JSON), Anotações, Favoritos, Progresso, Pesquisa, Versões, Histórico, Backup, Configurações, Sobre (com a logo).
- **"Ir para referência"** (ex.: "Jo 3:16") em `lib/models/reference_parser.dart`.
- **Atualização automática:** o app lê `releases/latest` do GitHub e oferece o APK novo (`lib/services/updater.dart`). Só builds assinados com a chave fixa viram "latest"; os outros saem como pré-versão.

## Infraestrutura
- **Build:** `.github/workflows/biblia-apk.yml`. Roda a cada push em `biblia_jg/**`, a menos que o commit tenha `[skip ci]`. Faz analyze, testes, baixa as Bíblias, assina e publica o release `biblia-build-N`.
- **Assinatura:** 4 secrets no repositório (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`). O workflow tolera espaços e texto extra colado junto. O backup da chave está no Google Drive do dono: `chave-assinatura-biblia-jg.txt`. Impressão digital: `0E:F3:62:0F:…:D3:18`.
- **Supabase:** projeto `biblia-jg` (id `ayjsoixzroxkrnkpkkip`, São Paulo, plano gratuito).
  - Edge Function `ai-verse` (código em `supabase/functions/ai-verse/`) faz o proxy para o Gemini. Usa o secret `GEMINI_API_KEY`, já salvo no Supabase.
  - Aceita usuário logado **ou** o app, com `x-app-key` (o hash fica na tabela `ai_config`) e `x-device-id`.
  - Limites: 80 pedidos por dia por aparelho, 400 por dia no total.
  - Tarefas: `explain`, `commentary`, `term`, `devotional`, `story`, `quiz`, `sermon`, `chat`.
  - Perfis: `assembleiano` (padrão), `geral`, `batista`, `reformado`, `academico`, `catolico`.
- **IA no app:** `lib/services/ai_service.dart` (chave do app e chave anon do Supabase) e `lib/screens/ai_chat_screen.dart`.
- **Músicas de fundo (na nuvem, nunca na pasta de músicas do tablet — pedido do dono):**
  - Bucket **privado** `musicas` no Supabase Storage (limite 50 MB por arquivo no plano grátis). Arquivos em Opus 48 kbps (`.ogg`) e a lista em `musicas.json` (`file`, `title`, `seconds`, `bytes`).
  - Edge Function `music` (`supabase/functions/music/`): confere o `x-app-key` (mesmo hash de `ai_config`) e devolve a lista com links assinados de 12 h.
  - App: `lib/services/music_player.dart` (just_audio, toca online; "Baixar" guarda só na área interna do app, com opção de apagar) e `lib/screens/music_screen.dart` (tela + barrinha embaixo da leitura).
  - Originais em `D:\Claude Code\musicas\MP3` (2,3 GB, 31 faixas, 16,7 h); convertidos em `D:\Claude Code\musicas\nuvem`. Para adicionar músicas: converter com `ffmpeg -i X.mp3 -vn -c:a libopus -b:a 48k X.ogg`, subir no bucket e atualizar `musicas.json` (o app não precisa de nova versão).
  - Plano grátis: 1 GB de armazenamento e ~5 GB de tráfego/mês (≈ 230 h de música online/mês; as baixadas não gastam).

- **IA com reserva:** a chave Gemini é do plano grátis (o `gemini-flash-latest` só dá 20 pedidos/dia). A `ai-verse` tenta os modelos de `GEMINI_FALLBACK_MODELS` (padrão: flash-lite) quando recebe 429/503. Para acabar com o limite, ativar faturamento no Google AI Studio.
- **Fundos do editor de imagem:** bucket **público** `fundos` (68 fotos de 1440 px + miniaturas `t-*.jpg` + `fundos.json` com tema, autor e licença). Fotos do Wikimedia Commons ("Quality images", só CC0, domínio público e CC BY — sem SA), geradas por `tool/fetch_backgrounds.py`; o editor mostra o crédito do autor. Também: foto da galeria, degradês prontos e próprios, cores lisas, escurecer, desfocar, cor e sombra do texto.
- **Voz da leitura:** `lib/screens/voice_screen.dart` — escolhe o mecanismo (Google é bem mais natural que o da Samsung), a voz (online = mais natural), velocidade e tom; fica salvo.
- **Login Google + sincronização (feito):** Google Cloud do projeto do Gemini (`gen-lang-client-0231835938`, nº 703427545959, conta mrparfum.ofc), Google Auth Platform em modo **Teste** (usuários de teste: mrparfum.ofc e joabegoncalvess — outra conta precisa ser adicionada em Público-alvo ou o app publicado). Clientes OAuth: Web `703427545959-3dmu…hhg1` (vai em `serverClientId` e nos Client IDs do Supabase) e Android (pacote `com.jgcompany.biblia_jg`, SHA-1 `4D:D5:E2:72:48:27:67:2D:FA:6F:93:65:C9:A8:A1:65:D7:3E:E5:C3`). Supabase: provedor Google ligado sem secret, "Skip nonce checks" ligado. App: `google_sign_in` 7 → id_token → `/auth/v1/token?grant_type=id_token`; sessão em SharedPreferences (`lib/services/account_service.dart`). Tabela `user_sync` (1 linha por usuário, jsonb com o backup + ajustes, RLS só do dono). `lib/services/sync.dart`: ao abrir, traz da nuvem se ela for mais nova que a última sync; ao sair do app, envia.

- **Livros (PDF) e EBD:** exigem login. Bucket privado `livros` (pasta = id do usuário, RLS no storage; até 50 MB por PDF). Tabelas `books` (kind livro/ebd, pasta, ano, trimestre, última página, lições) e `book_ink` (traços por página, coordenadas 0..1), as duas com RLS do dono. `lib/services/books_service.dart` (upload, download para o cache do app, tinta local + nuvem), `lib/screens/library_screen.dart` (abas Livros/EBD, por pasta e por ano/trimestre) e `lib/screens/pdf_reader_screen.dart` (pdfrx; caneta, marca-texto, borracha, cores, espessura, desfazer, limpar; Bíblia ao lado no tablet; chips com as referências achadas no texto da página; lições: marcar à mão ou "encontrar sozinho" procurando "Lição N" no topo das páginas). O `flutter test` local no Windows falha porque o pdfrx compila um pedaço em C (precisa de compilador); no GitHub (Linux) roda normal.

- **Dicionário bíblico:** só domínio público. O PDF do Vine que o dono tem em Downloads é escaneamento pirata da edição CPAD (2002, com Unger/White) — **não usar**. Fontes: dataset HF `JWBickel/BibleDictionaries` (Easton 3.963, Smith 4.560, Hitchcock 2.622, Torrey 623 verbetes). Tradução com `tool/translate_dictionaries.py` (retoma de onde parou; saída em `D:\Claude Code\dicionarios-biblia\pt\*.jsonl`) chamando a Edge Function **temporária** `translate-dict` (Gemma 4, para não gastar a cota do Gemini da IA do app — apagar ao terminar). Publicação: bucket público `dicionarios` com `index.json` ([{code,name,about,count,version}]) e `<code>.json` ([{t,e,x}]); o app baixa e guarda (`lib/services/dictionary_service.dart`, `lib/screens/dictionary_screen.dart`): busca, parágrafos com cores, anotação, favorito, referências clicáveis; marcações entram na sincronização (`dict_marks`). Vine 1940 (domínio público) ficou de fora: o StudyLight bloqueia robôs (403) e não achei outra fonte aberta.
- **Hinário:** 89 hinos de domínio público do Wikisource (Cantor Cristão numerado + hinos tradicionais), `tool/fetch_hymns.py` → bucket público `hinos/hinos.json`. A Harpa Cristã é da CPAD: entra só pelo botão "Importar meu hinário" (PDF/TXT numerado → `parseHymnText`), salvo na tabela `user_hymnals` (RLS do dono). Tela com busca por número/trecho, favoritos, tamanho da letra, copiar/compartilhar e modo apresentação.

- **Mapas:** `lib/screens/maps_screen.dart` + `lib/services/places.dart`. Satélite Sentinel-2 cloudless da EOX (gratuito para uso não comercial, com crédito na tela). Lugares: `assets/data/places.json` (1.309 lugares do OpenBible, CC BY) gerado por `tool/build_places.py`, que tira o nome em português do próprio texto da ARA/ARC (Bethel → Betel, Kadesh-barnea → Cades-Barneia); poucos nomes raros ficaram em inglês. Histórias animadas em `assets/data/map_stories.json` (Abraão, Êxodo, vida de Jesus, 1ª e 2ª viagens de Paulo, viagem a Roma, reinos e impérios com regiões coloridas): câmera "voa" entre as etapas, ponto pulsando, etiqueta no estilo do vídeo de referência, rota se desenhando, referência abre a Bíblia. "Explorar o mapa" com busca; botão "Mapa" no versículo mostra os lugares citados nele.
- **Lembrete da EBD:** domingo às 7h com a lição do dia (`lib/services/ebd_reminder.dart`): a k-ésima lição marcada cai no k-ésimo domingo do trimestre da revista; aparece também no topo da aba EBD.

## Fase 2 (build 24): dores dos usuários, nova navegação e revisão geral
- **Pesquisa das dores** em `docs/pesquisa-dores.md` (com fontes e o que o app faz para cada uma).
- **Navegação nova** (`lib/screens/home_shell.dart`): 5 abas — Hoje, Bíblia, Estudo, Biblioteca, Mais — em barra lateral no tablet e barra inferior no celular; o menu lateral antigo saiu. `AppState.openAt()` abre a aba Bíblia; `goTo()` só muda o capítulo (painéis). `AppState.requestTab(1, focus: true)` inicia o modo foco.
- **Hoje** (`today_screen.dart`): versículo do dia com foto, continuar leitura, sessão de 5 min (modo foco), meta diária e sequência (tabela `activity`), plano flexível ou "Por onde começar?", "Preciso de uma palavra", oração, memorização, devocional.
- **Novas telas:** `needs_screen.dart` (Palavra para o momento, 15 temas), `prayer_screen.dart` (diário de oração + Orar agora), `memorize_screen.dart` (repetição espaçada), `widgets/compare_sheet.dart` (comparar versões). No leitor: "Entender" (resumo do capítulo / introdução do livro, IA com cache), "Explicar simples", "Comparar", "Memorizar". Na EBD: "Preparar a aula com IA".
- **Banco v2** (`user_db.dart`): tabelas `activity`, `prayers`, `memory` (entram no backup e na sincronização).
- **Sincronização sem perda** (`sync.dart`): nuvem mais nova e nada mudou aqui → substitui; mudou nos dois → junta (`importAll(replace: false)` com `_mergeExisting`) e envia. Roda ao abrir, ao voltar e ao sair. A cópia leva também plano de leitura, favoritos do hinário e meta. Sessão vencida aparece na tela (`AccountService.sessionExpired`).
- **Correções da revisão de código:** tinta do PDF com fila de páginas pendentes; lista de livros guardada para uso sem internet; hinários importados antes do login sobem para a conta; marcações do dicionário com gravação atômica; player avisa erro e renova link vencido; desfazer/limpar na página riscada; palma da mão ignorada com caneta; botão Mapa no 1º toque; referências da IA e do quiz abrem em painel; "Tentar de novo" da IA; permissão de notificação pedida na 1ª abertura; "Memorizar" não zera progresso; confirmação ao trocar de plano.
- **Prévia no navegador (para revisar layout no PC):** cópia em `D:\Claude Code\mapas-biblia\preview-src` com `tool/app_preview.dart` (banco via `sqflite_common_ffi_web`), servida pelo launch `mapas-biblia-preview` (porta 4975). O `flutter test` local não roda no Windows (pdfrx precisa de compilador C); os testes rodam no GitHub.
- **Pendente da revisão:** chave do app no código público (trocar quando o repositório ficar privado), "Ler junto", alvos de toque de 30–32 dp nas paletas de cor, capítulo longo em `Column` não preguiçosa.

## Fase 3 (build 26): histórias ilustradas e narradas, atlas e viagens de Paulo
- **Histórias bíblicas** (`lib/screens/stories_screen.dart`, `story_player_screen.dart`, `lib/services/stories.dart`): 31 histórias completas (199 cenas) em três coleções (Paulo e a igreja, vida de Jesus, Antigo Testamento). Cada cena tem texto próprio (80–115 palavras, fiel à passagem), referência que abre a Bíblia, ilustração, narração e, quando há lugar, o ponto no mapa. O player passa sozinho de cena em cena; a janela pequena troca entre cena e mapa; no fim mostra uma reflexão e a próxima história. A lista antiga (contada pela IA na hora) virou "Outras histórias, contadas pela IA" (`AiStoriesScreen`).
- **Efeito 3D** (`lib/widgets/parallax_image.dart` + `shaders/parallax.frag`): cada ilustração tem um mapa de profundidade (Depth Anything V2 small, gerado no PC); o shader desloca o que está perto mais do que o fundo enquanto a câmera se move. Há um teste automático de orientação da textura (OpenGL ES) e, se o shader não carregar, cai num zoom suave. Dá para desligar no menu do player.
- **Mídia na nuvem** (bucket público `historias`): `img/<chave>.jpg` (1600 px), `thumb/`, `dep/` (profundidade), `audio/<história>-<n>.mp3` e `historias.json` (índice). O app traz um índice embutido (`assets/data/historias.json`) e confere o da nuvem ao abrir: **ilustrações e narrações novas chegam sem atualizar o app**. As cenas dizem se já têm ilustração (`"i"`) e narração (`"a"`); sem narração gravada, usa a voz do aparelho; sem ilustração, mostra o mapa ou um quadro com o título.
- **Como as mídias são feitas** (pasta de trabalho no PC do dono: `D:\Claude Code\mapas-biblia\historias`; cópia dos fontes em `tool/historias/`):
  - `outline.py` = roteiro (cenas, lugares, referências); `images.py` = descrição de cada ilustração; `texto/<id>.json` = narração; `check_texto.py` confere.
  - Ilustrações: geradas no Gemini pelo navegador (conta Pro do dono). O plano dá cerca de 40 imagens a cada janela de ~2 h; `grab.py` organiza os downloads em `raw/`.
  - `python midia.py imagens` prepara (1600 px, miniatura, profundidade) e envia; `python midia.py audio` narra com o Gemini TTS (cota grátis: ~10 por modelo por dia, ~40 por dia) e envia; ambos refazem o índice. O envio usa a Edge Function `historias-admin`, que só aceita a chave guardada em `.upload_key` nessa pasta (na função fica só o SHA-256).
- **Mapas** (`lib/screens/maps_screen.dart`, `lib/widgets/story_map.dart`): "Atlas bíblico" (`assets/data/map_stories.json`, gerado por `tool/historias/build_atlas.py`) com 8 mapas: as viagens de Paulo (as quatro rotas coloridas), as cartas de Paulo, Jerusalém nos dias de Jesus, a terra nos dias de Jesus, as doze tribos, o reino dividido, os exílios e os impérios. "Viagens e rotas" abre as histórias com rota já no modo mapa. Limites e rotas são aproximados.
- Testes novos em `test/stories_test.dart`.

## Fase 4 (build 28): Panorama bíblico (quadros de estudo)
O dono mostrou vídeos de livros do tipo "panorama bíblico" (árvore genealógica, cronologia dos reis, tabela dos profetas, ficha de cada livro) e pediu esse estilo no app. Feito com texto e desenho próprios (nada copiado dos livros dos vídeos):
- `lib/screens/panorama_screen.dart` (entrada em Estudo > Panorama bíblico; profetas; grade e ficha dos 66 livros), `panorama_tree.dart` (árvore de Abraão às doze tribos, com descendentes; modo "Apresentar" passo a passo com a voz do aparelho), `panorama_kings.dart` (linha do tempo em escala de Israel e Judá, cor pela avaliação do rei, marcos no eixo). Modelo em `lib/services/panorama.dart`; narrador de passos em `lib/services/step_narrator.dart`.
- Dados em `assets/data/panorama.json`, gerados por `tool/panorama/build_panorama.py` (árvore, reis e profetas escritos ali; fichas em `livros_a/b/c.json`). `check_livros.py` confere o formato e `check_refs.py` confere cada referência contra o texto de uma Bíblia do app.
- A ficha do livro também abre pelo botão da lâmpada no leitor. Capítulos e versículos são contados na versão aberta; o versículo-chave é lido da própria Bíblia.
- Datas dos reis seguem a cronologia mais usada (Thiele), aproximadas. Testes em `test/panorama_test.dart`.

## Pendências
1. ~~Músicas de fundo~~ feito (player na nuvem, ver Infraestrutura). Ideias futuras: abaixar a música enquanto o "Ouvir" lê o versículo; tocar com a tela bloqueada (audio_service).
2. ~~Livros (PDF) + EBD~~ feito (falta: lembrete de domingo da lição da EBD). Leitor de PDF com pastas, anotação à mão (caneta, marca-texto, borracha, cores, desfazer), salvo por página. O módulo EBD: revista em PDF por ano e trimestre, lições marcadas (à mão ou pela IA), Bíblia ao lado, referências clicáveis, lembrete de domingo.
3. ~~Hinário~~ feito (ver Infraestrutura).
4. ~~Mapas~~ feito (ver Infraestrutura). Ideia futura: relevo 3D inclinado (MapLibre com terreno). Antes: Usar o OpenBible geodata (CC-BY, 1.293 lugares) com flutter_map/OSM, mais os lugares do versículo e jornadas (Êxodo, viagens de Paulo). "Vídeos 3D" só se o dono fornecer os vídeos.
5. **Dicionário.** Domínio público: Strong, Easton, Smith, ISBE 1915, traduzidos com o Gemini. Mais um importador de módulos MyBible/MySword e conversão de PDFs de dicionário que o dono tenha legitimamente, entregues de forma privada e não pelo repositório.
6. ~~Login Google + sincronização~~ feito (ver Infraestrutura).
7. **Repositório privado.** O dono quer o repositório privado. **Antes de mudar**, levar a atualização automática para o Supabase Storage (secret `SUPABASE_SERVICE_ROLE_KEY` no GitHub para o upload) e apontar `updater.dart` para lá. Senão o app para de achar as atualizações.

## Regras de conteúdo
Não usar dados com direito autoral de terceiros sem licença: os módulos do repositório `welitonevoc/biblia-codex` (Merrill, Vine Pro, Quem é Quem, Strong AMG/CPAD, revistas CPAD, devocionais Lucado/Hernandes/Bullón), os dicionários Wycliffe, Tyndale e Vine, e a Harpa Cristã. Esse repositório serve só como referência de funções. O inventário completo das funções dele foi feito nesta sessão; a ordem sugerida está acima.

## Desenvolvimento
```bash
cd biblia_jg
python3 tool/fetch_bibles.py          # baixa e monta as 22 versões em assets/bibles/
flutter pub get && flutter analyze && flutter test
```
O Flutter usado é o 3.47.9. O APK só é gerado no GitHub Actions (o ambiente da nuvem não tem o Android SDK).
