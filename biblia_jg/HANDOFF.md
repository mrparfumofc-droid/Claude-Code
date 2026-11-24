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

## Pendências
1. ~~Músicas de fundo~~ feito (player na nuvem, ver Infraestrutura). Ideias futuras: abaixar a música enquanto o "Ouvir" lê o versículo; tocar com a tela bloqueada (audio_service).
2. ~~Livros (PDF) + EBD~~ feito (falta: lembrete de domingo da lição da EBD). Leitor de PDF com pastas, anotação à mão (caneta, marca-texto, borracha, cores, desfazer), salvo por página. O módulo EBD: revista em PDF por ano e trimestre, lições marcadas (à mão ou pela IA), Bíblia ao lado, referências clicáveis, lembrete de domingo.
3. **Hinário.** Só hinos de domínio público, mais importação de hinário próprio. A Harpa Cristã é da CPAD.
4. **Mapas.** Usar o OpenBible geodata (CC-BY, 1.293 lugares) com flutter_map/OSM, mais os lugares do versículo e jornadas (Êxodo, viagens de Paulo). "Vídeos 3D" só se o dono fornecer os vídeos.
5. **Dicionário.** Domínio público: Strong, Easton, Smith, ISBE 1915, traduzidos com o Gemini. Mais um importador de módulos MyBible/MySword e conversão de PDFs de dicionário que o dono tenha legitimamente, entregues de forma privada e não pelo repositório.
6. ~~Login Google + sincronização~~ feito (ver Infraestrutura).
7. **Repositório privado.** O dono quer o repositório privado. **Antes de mudar**, levar a atualização automática para o Supabase Storage (secret `SUPABASE_SERVICE_ROLE_KEY` no GitHub para o upload) e apontar `updater.dart` para lá. Senão o app para de achar as atualizações.

## Regras de conteúdo
Não usar dados com direito autoral de terceiros sem licença: os módulos do repositório `welitonevoc/biblia-codex` (Merrill, Vine Pro, Quem é Quem, Strong AMG/CPAD, revistas CPAD, devocionais Lucado/Hernandes/Bullón), os dicionários Wycliffe, Tyndale e Vine, e a Harpa Cristã. Esse repositório serve só como referência de funções. O inventário completo das funções dele foi feito nesta sessão; a ordem sugerida está acima.

## Desenvolvimento
```bash
cd biblia_jg
python3 tool/fetch_bibles.py          # baixa e monta as 22 versões em assets/bibles/
flutter pub get && flutter analyze && flutter test   # 21 testes
```
O Flutter usado é o 3.47.9. O APK só é gerado no GitHub Actions (o ambiente da nuvem não tem o Android SDK).
